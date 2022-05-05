# frozen_string_literal: true

require 'csv'
require 'google/cloud/vision'

module Client
  class Vision
    class UnexpectedError < ::StandardError; end

    Activity = Struct.new(:status_id, :tweeted_at, :activity_time, :consumption_calory) do
      def to_csv
        attributes = %i[status_id tweeted_at activity_time consumption_calory].freeze
        CSV.generate do |csv|
          csv << attributes.map(&:to_s)
          csv << attributes.map { |attr| send attr }
        end
      end
    end

    def show(tweet)
      image_annotator = Google::Cloud::Vision.image_annotator
      descriptions = tweet.photo_urls.map do |url|
        response = image_annotator.text_detection(image: url)
        response.responses.first.text_annotations.first.description
      end

      activitify(tweet:, descriptions:)
    rescue StandardError => e
      raise UnexpectedError, e.message
    end

    private

    def activitify(tweet:, descriptions:)
      description = descriptions.select { |desc| desc.include? '合計活動時間' }.first
      return nil if description.nil?

      consumption_calory = description.scan(/(\d+\.\d+)kcal/).first&.first
      activity_time = description.scan(/((\d+)時間)?(\d+)分(\d+)秒/).first&.compact&.join(':')

      Activity.new(tweet.status_id, tweet.tweeted_at, activity_time, consumption_calory)
    end
  end
end
