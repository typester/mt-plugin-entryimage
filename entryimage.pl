package MT::Plugin::EntryImage;
use strict;
use warnings;
use base 'MT::Plugin';

our $VERSION = '0.01';

MT->add_plugin(__PACKAGE__->new({
    name        => 'EntryImage',
    author_name => 'KAYAC Inc.',
    author_link => 'http://www.kayac.com/',
    version     => $VERSION,
    description => 'エントリ画像プラグイン',
    settings    => MT::PluginSettings->new([
        [ enabled => { Default => 0, Scope => 'blog' } ],
    ]),
    blog_config_template => 'blog_config.tmpl',
    schema_version => 1,
}));

sub init_registry {
    my ($plugin) = @_;

    $plugin->registry({
        object_types => {
            entry => {
                entry_image_id => 'integer',
            },
        },

        tags => {
            function => {
                EntryImageID => sub {
                    my ($c, $params) = @_;
                    my $entry    = $c->stash('entry') or return;
                    my $image_id = $entry->entry_image_id or return;

                    my $asset = $plugin->entry_image($image_id)
                        or return;

                    return $image_id;

                },
            },
        },

        callbacks => {
            'MT::App::CMS::template_source.edit_entry' => sub {
                my ($cb, $app, $tmpl) = @_;
                return unless $plugin->enabled($app);

                my $html = $plugin->load_tmpl('sidebar.tmpl')->text;
                $$tmpl =~
                    s!(<mtapp:widget.*?id="entry-publishing-widget")!$html\n$1!s;
            },
            'MT::App::CMS::template_source.asset_list' => sub {
                my ($cb, $app, $tmpl) = @_;
                return unless $app->param('plugin_entry_image');

                my $html =
                    '<input type="hidden" name="plugin_entry_image" value="1" />';
                $$tmpl =~ s!(<form.*?name="select_asset".*?>)!$1\n$html!;
            },
            'MT::App::CMS::template_source.asset_upload' => sub {
                my ($cb, $app, $tmpl) = @_;
                return unless $app->param('plugin_entry_image');

                my $html =
                    '<input type="hidden" name="plugin_entry_image" value="1" />';
                $$tmpl =~ s!(<form.*?id="upload-form".*?>)!$1\n$html!;
            },
            'MT::App::CMS::template_source.asset_insert' => sub {
                my ($cb, $app, $tmpl) = @_;
                return unless $app->param('plugin_entry_image');

                my $asset = $plugin->entry_image($app->param('id'))
                    or return;

                my $t = $plugin->load_tmpl('insert_script.tmpl');
                $t->param( asset_id  => $app->param('id') );
                $t->param( asset_url => $plugin->entry_image_url($asset) );

                my $js = $t->output;
                $$tmpl =~
                    s!var Node .*(<mt:unless name="extension_message">)!$js\n$1!s;
            },
            'MT::App::CMS::cms_pre_save.entry' => sub {
                my ($cb, $app, $entry) = @_;
                return unless $plugin->enabled($app);

                my $asset;
                my $id = $app->param('entryimage_id');
                if ($id) {
                    $asset = $plugin->entry_image($id);
                }

                unless ($asset) {
                    # remove
                    $entry->entry_image_id(undef);
                    return 1;
                }

                $entry->entry_image_id($id);

                1;
            },

            'MT::App::CMS::post_run' => sub {
                my ($cb, $app) = @_;
                return unless $plugin->enabled($app);

                my $tmpl = $app->response_content;
                return unless $tmpl && $tmpl->isa('MT::Template');

                if (my $id = $tmpl->param('entry_image_id')) {
                    my $asset = MT::Asset::Image->load({ id => $id });

                    if ($asset) {
                        $tmpl->param( entry_image_asset => $asset );
                        $tmpl->param(
                            entry_image_url => $plugin->entry_image_url($asset));
                    }
                }
            },
        },
    });

}

sub entry_image {
    my ($self, $id) = @_;
    MT::Asset::Image->load({ id => $id });
}

sub entry_image_url {
    my ($self, $id_or_asset) = @_;
    my $asset = $id_or_asset->isa('MT::Asset')
        ? $id_or_asset
        : $self->entry_image($id_or_asset);

    my $width = 218; # widget content width

    my ($url) = $asset->image_width > $width
        ? $asset->thumbnail_url( Width => $width )
        : $asset->thumbnail_url;

    $url;
}

sub enabled {
    my ($self, $app) = @_;
    my $blog = $app->blog or return;

    $self->get_config_value( enabled => 'blog:' . $blog->id );
}
        
1;
