# frozen_string_literal: true

class NewEpisodeRecordService
  attr_writer :app, :via, :ga_client, :page_category
  attr_reader :episode_record

  def initialize(user, episode_record)
    @user = user
    @episode_record = episode_record
  end

  def save!
    @episode_record.user = @user
    @episode_record.work = @episode_record.episode.work
    @episode_record.detect_locale!(:comment)

    ActiveRecord::Base.transaction do
      @episode_record.record = @user.records.create!
      @episode_record.save!
      @episode_record.update_share_record_status
      @episode_record.share_to_sns
      save_activity
      update_episode_record_comments_count
      finish_tips
      update_latest_status
      create_ga_event
    end

    true
  end

  private

  def save_activity
    return if @episode_record.multiple_episode_record.present?
    CreateEpisodeRecordActivityJob.perform_later(@user.id, @episode_record.id)
  end

  def finish_tips
    FinishUserTipsJob.perform_later(@user, "record") if @user.records.initial?(@episode_record)
  end

  def update_latest_status
    latest_status = @user.latest_statuses.find_by(work: @episode_record.work)
    latest_status.append_episode(@episode_record.episode) if latest_status.present?
  end

  def create_ga_event
    return if @ga_client.blank?
    @ga_client.events.create(:records, :create, el: "Episode", ds: @via)
  end

  def update_record_comments_count
    @episode_record.episode.increment!(:episode_record_comments_count) if @episode_record.comment.present?
  end
end
