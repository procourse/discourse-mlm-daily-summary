# name: discourse-mlm-daily-summary
# about: Brings back the daily summary email for mailing list mode users.
# version: 0.1
# author: Joe Buhlig joebuhlig.com
# url: https://www.github.com/joebuhlig/discourse-mlm-daily-summary

enabled_site_setting :mlm_daily_summary_enabled

DiscoursePluginRegistry.serialized_current_user_fields << "user_mlm_daily_summary_enabled"

load File.expand_path('../lib/discourse_mlm_daily_summary/engine.rb', __FILE__)