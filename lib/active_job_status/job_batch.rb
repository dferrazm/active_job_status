module ActiveJobStatus
  class JobBatch

    attr_reader :batch_id
    attr_reader :job_ids
    attr_reader :expire_in

    def initialize(batch_id:, job_ids:, expire_in: 259200, store_data: true)
      @batch_id = batch_id
      @job_ids = job_ids
      @expire_in = expire_in
      # the store_data flag is used by the ::find method return a JobBatch
      # object without re-saving the data
      self.store_data if store_data
    end

    def store_data
      ActiveJobStatus.store.delete(@batch_id) # delete any old batches
      if ActiveJobStatus.store.class.to_s == "ActiveSupport::Cache::RedisStore"
        ActiveJobStatus.store.sadd(@batch_id, @job_ids)
        ActiveJobStatus.store.expire(@batch_id, expire_in)
      else
        ActiveJobStatus.store.write(@batch_id, @job_ids, expires_in: @expire_in)
      end
    end

    def add_jobs(job_ids:)
      @job_ids = @job_ids + job_ids
      if ActiveJobStatus.store.class.to_s == "ActiveSupport::Cache::RedisStore"
        # Save an extra redis query and perform atomic operation
        ActiveJobStatus.store.sadd(@batch_id, job_ids)
      else
        existing_job_ids = ActiveJobStatus.store.fetch(@batch_id)
        ActiveJobStatus.store.write(@batch_id, existing_job_ids.to_a | job_ids)
      end
    end

    def completed?
      job_statuses = []
      @job_ids.each do |job_id|
        job_statuses << ActiveJobStatus::JobStatus.get_status(job_id: job_id)
      end
      !job_statuses.any?
    end

    def self.find(batch_id:)
      if ActiveJobStatus.store.class.to_s == "ActiveSupport::Cache::RedisStore"
        job_ids = ActiveJobStatus.store.smembers(batch_id)
      else
        job_ids = ActiveJobStatus.store.fetch(batch_id).to_a
      end

      ActiveJobStatus::JobBatch.new(batch_id: batch_id,
                                    job_ids: job_ids,
                                    expire_in: @expire_in,
                                    store_data: false)
=begin
      if ActiveJobStatus.store.class.to_s == "ActiveSupport::Cache::RedisStore"
        ActiveJobStatus.store.smembers(batch_id)
      else
        ActiveJobStatus.store.fetch(batch_id).to_a
      end
=end
    end

    private


    def write(key, job_ids, expire_in=nil)
    end
  end
end

