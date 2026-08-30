module Jobbable
  extend ActiveSupport::Concern

  included do
    attr_accessor :jobbable_cancelled

    def jobbable_cancelled?
      jobbable_cancelled
    end
  end

  def jobbable_jobs(job_classes)
    job_classes = Array(job_classes) unless job_classes.is_a?(Array)
    SolidQueue::Job
      .where(class_name: job_classes, finished_at: nil)
  end

  def jobbable_jobs_mine(job_classes)
    jobbable_jobs(job_classes)
      .select { |job| jobbable_job_targets_me?(job) }
      .to_a
  end

  def jobbable_cleanup_jobs(job_classes)
    jobbable_jobs_mine(job_classes).each do |job|
      if (claimed = job.claimed_execution)
        claimed.failed_with(StandardError.new("Cancelled via jobbable_cleanup_jobs"))
      else
        job.discard
      end
      job.destroy! if SolidQueue::Job.exists?(job.id)
    rescue SolidQueue::Execution::UndiscardableError => e
      Rails.logger.warn("[jobbable_cleanup_jobs] job=#{job.id}: #{e.message}")
    end
  end

  def jobbable_job_targets_me?(job)
    raw = job.arguments
    payload =
      case raw
      when String
        JSON.parse(raw)
      when Hash
        raw
      else
        return false
      end
    args = payload["arguments"] || payload[:arguments] || payload
    Array(args).first.to_i == id
  rescue JSON::ParserError
    false
  end
end
