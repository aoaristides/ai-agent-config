# frozen_string_literal: true

module CaptureAdapters
  class GenericText
    def self.capture(options, stdin:)
      content, inferred_title = read_input(options[:file], stdin)
      title = options[:title] || inferred_title || "#{options[:source]} capture"
      {
        source: { provider: options[:source], title: title.strip },
        content: content.strip
      }
    end

    def self.read_input(file, stdin)
      return [stdin.read, nil] if file.nil? || file == '-'

      path = File.expand_path(file)
      content = File.read(path, encoding: 'UTF-8')
      title = File.basename(path, File.extname(path))
      [content, title]
    end
    private_class_method :read_input
  end
end
