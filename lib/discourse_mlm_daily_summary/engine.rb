module DiscourseMlmDailySummary
  class Engine < ::Rails::Engine
    isolate_namespace DiscourseMlmDailySummary

    config.after_initialize do

      require_dependency 'user_notifications'
      class ::UserNotifications
        def mailing_list(user, opts={})
          @since = opts[:since] || 12.days.ago
          @since_formatted = short_date(@since)

          topics = Topic
            .joins(:posts)
            .includes(:posts)
            .for_digest(user, 100.years.ago)
            .where("posts.created_at > ?", @since)

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
byebug
          apply_notification_styles(build_email(@user.email, opts))
        end
      end 

      module ::Jobs
        class EnqueueMlmDailySummary < Jobs::Scheduled
          every 1.day

          def execute(args)
            return if SiteSetting.disable_mailing_list_mode?
            target_user_ids.each do |user_id|
              Jobs.enqueue(:user_email, type: :mailing_list, user_id: user_id)
            end
          end

          def target_user_ids
            # Users who want to receive daily mailing list emails
            User.real
                .activated
                .not_suspended
                .not_blocked
                .where(id: 1)
                .pluck(:id)
            #     .joins(:user_option)
            #     .where(staged: false, user_options: { mailing_list_mode: true, mailing_list_mode_frequency: 0 })
            #     .where("#{!SiteSetting.must_approve_users?} OR approved OR moderator OR admin")
            #     .where("date_part('hour', first_seen_at) = date_part('hour', CURRENT_TIMESTAMP)")           # where the hour of first_seen_at is the same as the current hour
            #     .where("COALESCE(first_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - '23 HOURS'::INTERVAL") # don't send unless you've been around for a day already
            #     .pluck(:id)
          end

        end
      end

    end

  end
end