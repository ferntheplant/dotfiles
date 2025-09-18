//
/* You may copy+paste this file and use it as it is.
 *
 * If you make changes to your about:config while the program is running, the
 * changes will be overwritten by the user.js when the application restarts.
 *
 * To make lasting changes to preferences, you will have to edit the user.js.
 */

/****************************************************************************
 * Betterfox                                                                *
 * "Ad meliora"                                                             *
 * version: 142                                                             *
 * url: https://github.com/yokoffing/Betterfox                              *
****************************************************************************/

/****************************************************************************
 * SECTION: FASTFOX                                                         *
****************************************************************************/
/** GENERAL ***/
user_pref("content.notify.interval", 100000);

/** GFX ***/
user_pref("gfx.canvas.accelerated.cache-size", 512);
user_pref("gfx.content.skia-font-cache-size", 20);

/** DISK CACHE ***/
user_pref("browser.cache.disk.enable", false);

/** MEMORY CACHE ***/
user_pref("browser.sessionhistory.max_total_viewers", 4);

/** MEDIA CACHE ***/
user_pref("media.memory_cache_max_size", 65536);
user_pref("media.cache_readahead_limit", 7200);
user_pref("media.cache_resume_threshold", 3600);

/** IMAGE CACHE ***/
user_pref("image.mem.decode_bytes_at_a_time", 32768);

/** NETWORK ***/
user_pref("network.http.max-connections", 1800);
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.max-urgent-start-excessive-connections-per-host", 5);
user_pref("network.http.pacing.requests.enabled", false);
user_pref("network.dnsCacheExpiration", 3600);
user_pref("network.ssl_tokens_cache_capacity", 10240);

/** SPECULATIVE LOADING ***/
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("browser.places.speculativeConnect.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.predictor.enabled", false);

/** EXPERIMENTAL ***/
user_pref("layout.css.grid-template-masonry-value.enabled", true);

/****************************************************************************
 * SECTION: SECUREFOX                                                       *
****************************************************************************/
/** TRACKING PROTECTION ***/
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.trackingprotection.allow_list.baseline.enabled", true);
user_pref("privacy.trackingprotection.allow_list.convenience.enabled", true);
user_pref("browser.download.start_downloads_in_tmp_dir", true);
user_pref("browser.helperApps.deleteTempFileOnExit", true);
user_pref("browser.uitour.enabled", false);
user_pref("privacy.globalprivacycontrol.enabled", true);

/** OCSP & CERTS / HPKP ***/
user_pref("security.OCSP.enabled", 0);
user_pref("security.pki.crlite_mode", 2);
user_pref("security.csp.reporting.enabled", false);

/** SSL / TLS ***/
user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
user_pref("browser.xul.error_pages.expert_bad_cert", true);
user_pref("security.tls.enable_0rtt_data", false);

/** DISK AVOIDANCE ***/
user_pref("browser.privatebrowsing.forceMediaMemoryCache", true);
user_pref("browser.sessionstore.interval", 60000);

/** SHUTDOWN & SANITIZING ***/
user_pref("browser.privatebrowsing.resetPBM.enabled", true);
user_pref("privacy.history.custom", true);

/** SEARCH / URL BAR ***/
user_pref("browser.urlbar.trimHttps", true);
user_pref("browser.urlbar.untrimOnUserInteraction.featureGate", true);
user_pref("browser.search.separatePrivateDefault.ui.enabled", true);
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.groupLabels.enabled", false);
user_pref("browser.formfill.enable", false);
user_pref("network.IDN_show_punycode", true);

/** PASSWORDS ***/
user_pref("signon.formlessCapture.enabled", false);
user_pref("signon.privateBrowsingCapture.enabled", false);
user_pref("network.auth.subresource-http-auth-allow", 1);
user_pref("editor.truncate_user_pastes", false);

/** MIXED CONTENT + CROSS-SITE ***/
user_pref("security.mixed_content.block_display_content", true);
user_pref("pdfjs.enableScripting", false);

/** EXTENSIONS ***/
user_pref("extensions.enabledScopes", 5);

/** HEADERS / REFERERS ***/
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

/** CONTAINERS ***/
user_pref("privacy.userContext.ui.enabled", true);

/** SAFE BROWSING ***/
user_pref("browser.safebrowsing.downloads.remote.enabled", false);

/** MOZILLA ***/
user_pref("permissions.default.desktop-notification", 2);
user_pref("permissions.default.geo", 2);
user_pref("geo.provider.network.url", "https://beacondb.net/v1/geolocate");
user_pref("browser.search.update", false);
user_pref("permissions.manager.defaultsUrl", "");
user_pref("extensions.getAddons.cache.enabled", false);

/** TELEMETRY ***/
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("datareporting.usage.uploadEnabled", false);

/** EXPERIMENTS ***/
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");

/** CRASH REPORTS ***/
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

/****************************************************************************
 * SECTION: PESKYFOX                                                        *
****************************************************************************/
/** MOZILLA UI ***/
user_pref("browser.privatebrowsing.vpnpromourl", "");
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.preferences.moreFromMozilla", false);
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.aboutwelcome.enabled", false);

/** AI ***/
user_pref("browser.ml.enable", false);
user_pref("browser.ml.chat.enabled", false);

/** FULLSCREEN NOTICE ***/
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");
user_pref("full-screen-api.warning.timeout", 0);

/** URL BAR ***/
user_pref("browser.urlbar.trending.featureGate", false);

/** NEW TAB PAGE ***/
user_pref("browser.newtabpage.activity-stream.default.sites", "");
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);

/** POCKET ***/
user_pref("extensions.pocket.enabled", false);

/** DOWNLOADS ***/
user_pref("browser.download.manager.addToRecentDocs", false);

/** PDF ***/
user_pref("browser.download.open_pdf_attachments_inline", true);

/** TAB BEHAVIOR ***/
user_pref("browser.bookmarks.openInTabClosesMenu", false);
user_pref("browser.menu.showViewImageInfo", true);


/****************************************************************************
 * START: MY OVERRIDES                                                      *
****************************************************************************/
// visit https://github.com/yokoffing/Betterfox/wiki/Common-Overrides
// visit https://github.com/yokoffing/Betterfox/wiki/Optional-Hardening
// Enter your personal overrides below this line:



/****************************************************************************
 * SECTION: SMOOTHFOX                                                       *
****************************************************************************/
// visit https://github.com/yokoffing/Betterfox/blob/main/Smoothfox.js
// Enter your scrolling overrides below this line:



/****************************************************************************
 * END: BETTERFOX                                                           *
****************************************************************************/


user_pref("accessibility.typeaheadfind.flashBar", 0);
user_pref("app.update.auto", false);
user_pref("browser.download.autohideButton", false);
user_pref("browser.download.lastDir", "/Users/fjorn/Downloads");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtabpage.pinned", "[{\"url\":\"https://google.com\",\"label\":\"@google\",\"searchTopSite\":true}]");
user_pref("browser.search.region", "US");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage", "chrome://browser/content/blanktab.html");
user_pref("browser.tabs.inTitlebar", 1);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.translations.panelShown", true);
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"_d7742d87-e61d-4b78-b8a1-b469842139fa_-browser-action\",\"_testpilot-containers-browser-action\",\"_aecec67f-0d10-4fa7-b7c7-609a2db280cf_-browser-action\",\"treestyletab_piro_sakura_ne_jp-browser-action\",\"_7be2ba16-0f1e-4d93-9ebc-5164397477a9_-browser-action\",\"_tst-search-browser-action\",\"tab-session-manager_sienori-browser-action\",\"jid1-zadieub7xozojw_jetpack-browser-action\",\"tst-active-and-total-tabs-counter_irvinm_addons_mozilla_org-browser-action\",\"_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action\",\"addon_darkreader_org-browser-action\",\"_bbb880ce-43c9-47ae-b746-c3e0096c5b76_-browser-action\",\"_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action\",\"_react-devtools-browser-action\",\"prodtodolist_gmail_com-browser-action\"],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"urlbar-container\",\"customizableui-special-spring2\",\"save-to-pocket-button\",\"unified-extensions-button\",\"ublock0_raymondhill_net-browser-action\",\"firefoxcolor_mozilla_com-browser-action\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\"],\"TabsToolbar\":[\"workspaces-toolbar-button\",\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\",\"firefox-view-button\"],\"PersonalToolbar\":[\"import-button\",\"personal-bookmarks\"],\"statusBar\":[\"screenshot-button\",\"fullscreen-button\",\"status-text\"]},\"seen\":[\"developer-button\",\"sidebar-reverse-position-toolbar\",\"undo-closed-tab\",\"profile-manager\",\"workspaces-toolbar-button\",\"_aecec67f-0d10-4fa7-b7c7-609a2db280cf_-browser-action\",\"treestyletab_piro_sakura_ne_jp-browser-action\",\"_7be2ba16-0f1e-4d93-9ebc-5164397477a9_-browser-action\",\"_tst-search-browser-action\",\"firefoxcolor_mozilla_com-browser-action\",\"tab-session-manager_sienori-browser-action\",\"_testpilot-containers-browser-action\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\",\"jid1-zadieub7xozojw_jetpack-browser-action\",\"tst-active-and-total-tabs-counter_irvinm_addons_mozilla_org-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action\",\"addon_darkreader_org-browser-action\",\"_bbb880ce-43c9-47ae-b746-c3e0096c5b76_-browser-action\",\"_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action\",\"_react-devtools-browser-action\",\"prodtodolist_gmail_com-browser-action\",\"_d7742d87-e61d-4b78-b8a1-b469842139fa_-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"statusBar\",\"PersonalToolbar\",\"TabsToolbar\",\"unified-extensions-area\"],\"currentVersion\":20,\"newElementCount\":5}");
user_pref("browser.urlbar.placeholderName", "DuckDuckGo");
user_pref("browser.urlbar.placeholderName.private", "DuckDuckGo");
user_pref("browser.urlbar.quicksuggest.scenario", "offline");
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("dom.forms.autocomplete.formautofill", true);
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("extensions.pictureinpicture.enable_picture_in_picture_overrides", true);
user_pref("extensions.ui.dictionary.hidden", true);
user_pref("extensions.ui.extension.hidden", false);
user_pref("extensions.ui.locale.hidden", true);
user_pref("extensions.ui.sitepermission.hidden", true);
user_pref("floorp.Tree-type.verticaltab.optimization", false);
user_pref("floorp.bookmarks.bar.focus.mode", true);
user_pref("floorp.browser.nora.csk.data", "{\"gecko-toggle-sidebar\":{\"modifiers\":{\"alt\":false,\"ctrl\":true,\"meta\":false,\"shift\":false},\"key\":\"b\"}}");
user_pref("floorp.browser.sidebar.enable", false);
user_pref("floorp.browser.sidebar.is.displayed", false);
user_pref("floorp.browser.tabbar.settings", 1);
user_pref("floorp.browser.user.interface", 1);
user_pref("floorp.hide.unifiedExtensionsButtton", false);
user_pref("floorp.verticaltab.hover.enabled", true);
user_pref("media.videocontrols.picture-in-picture.video-toggle.enabled", false);
user_pref("permissions.default.desktop-notification", 2);
user_pref("print_printer", "Mozilla Save to PDF");
user_pref("privacy.donottrackheader.enabled", true);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("privacy.globalprivacycontrol.was_ever_enabled", true);
user_pref("sidebar.position_start", false);
