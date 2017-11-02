module DiscourseMlmDailySummary
  class Engine < ::Rails::Engine
    isolate_namespace DiscourseMlmDailySummary

    config.after_initialize do

      User.register_custom_field_type('user_mlm_daily_summary_enabled', :boolean)

      require_dependency 'user_notifications'
      class ::UserNotifications
        def mailing_list(user, opts={})
          prepend_view_path "plugins/discourse-mlm-daily-summary/app/views"

          @since = opts[:since] || 1.day.ago
          @since_formatted = short_date(@since)

          topics = Topic
            .joins(:posts)
            .includes(:posts)
            .for_digest(user, 100.years.ago)
            .where("posts.created_at > ?", @since)
            .order("posts.id")

          unless user.staff?
            topics = topics.where("posts.post_type <> ?", Post.types[:whisper])
          end

          @new_topics = topics.where("topics.created_at > ?", @since).uniq
          @existing_topics = topics.where("topics.created_at <= ?", @since).uniq
          @topics = topics.uniq

          return if @topics.empty?

          build_summary_for(user)
          opts = {
            from_alias: I18n.t('user_notifications.mailing_list.from', site_name: SiteSetting.title),
            subject: I18n.t('user_notifications.mailing_list.subject_template', email_prefix: @email_prefix, date: @date),
            mailing_list_mode: true,
            add_unsubscribe_link: true,
            unsubscribe_url: "#{Discourse.base_url}/email/unsubscribe/#{@unsubscribe_key}",
          }

          apply_notification_styles(build_email(@user.email, opts))
        end
      end 

      require_dependency 'user_serializer'
      class ::UserSerializer
        attributes :user_mlm_daily_summary_enabled

        def user_mlm_daily_summary_enabled
          if !object.custom_fields["user_mlm_daily_summary_enabled"]
            object.custom_fields["user_mlm_daily_summary_enabled"] = false
            object.save
          end
          object.custom_fields["user_mlm_daily_summary_enabled"]
        end
      end

      module ::Jobs
        class EnqueueMlmDailySummary < Jobs::Scheduled
          every 1.hour

          def execute(args)
            return if SiteSetting.disable_mailing_list_mode?
            target_user_ids.each do |user_id|
              Jobs.enqueue(:user_email, type: :mailing_list, user_id: user_id)
            end
          end

          def target_user_ids
            # Users who want to receive daily mailing list emails
            enabled_ids = UserCustomField.where(name: "user_mlm_daily_summary_enabled", value: "true").pluck(:user_id)
            User.real
                .activated
                .not_suspended
                .not_blocked
                .joins(:user_option)
                .where(id: enabled_ids)
                .where(staged: false)
                .where("#{!SiteSetting.must_approve_users?} OR approved OR moderator OR admin")
                .where("date_part('hour', first_seen_at) = date_part('hour', CURRENT_TIMESTAMP)")           # where the hour of first_seen_at is the same as the current hour
                .where("COALESCE(first_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - '23 HOURS'::INTERVAL") # don't send unless you've been around for a day already
                .pluck(:id)
          end

        end
      end

    end

  end
end