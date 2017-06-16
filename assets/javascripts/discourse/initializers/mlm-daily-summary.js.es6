import { observes } from 'ember-addons/ember-computed-decorators';
import { default as computed } from "ember-addons/ember-computed-decorators";
import EmailPreferencesController from 'discourse/controllers/preferences/emails';
import UserController from 'discourse/controllers/user';

export default {
  name: 'mlm_daily_summary',

  initialize(container){
    EmailPreferencesController.reopen({
      userMLMDailySummaryEnabled(){
        const user = this.get("model");
        return user.get("custom_fields.user_mlm_daily_summary_enabled");
      },

      @observes("model.custom_fields.user_mlm_daily_summary_enabled")
      _setUserMLMDailySummary(){
        var attrNames = this.get("saveAttrNames");
        attrNames.push('custom_fields');
        this.set("saveAttrNames", attrNames);
        const user = this.get("model");
        const userMLMDailySummaryEnabled = user.custom_fields.user_mlm_daily_summary_enabled;
        user.set("custom_fields.user_mlm_daily_summary_enabled", userMLMDailySummaryEnabled);
      }
    })
  }
}