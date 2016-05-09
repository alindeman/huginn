module Agents
  class DropboxFileAppender < Agent
    include DropboxConcern

    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    description <<-MD
      The Dropbox File Appender Agent is used to append text to files in Dropbox. It takes a file path and writes a line (or lines) of text to the end of the file at that path.

      #{'## Include the `dropbox-api` and `omniauth-dropbox` gems in your `Gemfile` and set `DROPBOX_OAUTH_KEY` and `DROPBOX_OAUTH_SECRET` in your environment to use Dropbox Agents.' if dependencies_missing?}

      * `path`: Relative path to the file within the Dropbox account. The file must already exist.

      The incoming event payload needs to have a `text` key. For example:

          {
            "text": "line1\nline2"
          }
    MD

    def default_options
      {
        'path' => '',
        'expected_receive_period_in_days' => '2'
      }
    end

    def validate_options
      unless options['path'].present?
        errors.add(:base, 'The `path` key is required.')
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(events)
      events.each do |event|
        text = event.payload['text'].to_s

        # Definitely a potential race condition here. Not worrying about it for
        # now.
        contents = dropbox.download(interpolated['path'])
        contents << "\n" unless contents.end_with?("\n")
        contents << text
        contents << "\n" unless text.end_with?("\n")

        dropbox.upload(interpolated['path'], contents)
      end
    end
  end
end
