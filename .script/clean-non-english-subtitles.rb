# generate wti-like YAML files to get a cleaner git diff
# see https://webtranslateit.com/en/docs/file_formats/yaml#syck-psych-and-ya2yaml
require 'ya2yaml'
require 'psych'

class SubtitleCleaner

  LOCALES = %i(de it fr pl sl).freeze

  def initialize(sourcefile)
    @sourcefile =  sourcefile
    @source = load_yaml(sourcefile)
    @current_locale = nil
  end

  def clean(locale)
    @current_locale = locale
    localized_subtitles = load_localized_yaml
    clean_title!(localized_subtitles)
    clean_sequences!(localized_subtitles)
    write_clean(localized_source_file, localized_subtitles)
    post_process(localized_source_file)
  end

  def clean_all
    LOCALES.each do |locale|
      clean(locale)
    end
  end

  private

  def clean_title!(localized)
    english_title   = @source['en'][witness_name]["chapter-#{chapter_number}"]['title']
    localized_title = localized[@current_locale.to_s][witness_name]["chapter-#{chapter_number}"]['title']
    if english_title == localized_title
      localized[@current_locale.to_s][witness_name]["chapter-#{chapter_number}"]['title'] = nil
    end
  end

  def clean_sequences!(localized)
    english_sequences = @source['en'][witness_name]["chapter-#{chapter_number}"]['subtitles'].keys.each do |k|
      es = @source['en'][witness_name]["chapter-#{chapter_number}"]['subtitles'][k]['text']
      ls = localized[@current_locale.to_s][witness_name]["chapter-#{chapter_number}"]['subtitles'][k]['text']
      if ls == es
        localized[@current_locale.to_s][witness_name]["chapter-#{chapter_number}"]['subtitles'][k]['text'] = nil
      end
    end
  end

  def write_clean(localized_source_file, localized_subtitles)
    puts "Write cleaned #{localized_source_file}"
    File.open(localized_source_file, 'w') do |f|
      f.puts localized_subtitles.ya2yaml({
          :indent_size          => 2,
          :hash_order           => nil,
          :minimum_block_length => 16,
          :printable_with_syck  => true,
          :escape_b_specific    => true,
          :escape_as_utf8       => true,
          :preserve_order       => true
        })
    end
  end

  def post_process(localized_source_file)
    # remove first line with three dashes to get a cleaner git diff
    `echo "$(tail -n +2 #{localized_source_file})" > #{localized_source_file}`
    # remove whitespace at the end of the line / after a key definition
    `sed -i '' -e 's/\:\s$/\:/g' #{localized_source_file}`
  end

  def witness_name
    @sourcefile.split('/').last.split('-')[0..1].join('-')
  end

  def chapter_number
    @sourcefile.split('/').last.split('-').last.split('.').first.to_i
  end

  def load_yaml(subtitle_file)
    Psych.load(File.open(subtitle_file, 'r'){ |f| f.read })
  end

  def load_localized_yaml
    load_yaml(localized_source_file)
  end

  def localized_source_file
    @sourcefile.gsub('./locales/en', "./locales/#{@current_locale}")
  end

end


english_subtitles = Dir['./locales/en/subtitles/**/*.yml']
english_subtitles.each do |subtitle_file|
  puts "Processing #{subtitle_file}"
  SubtitleCleaner.new(subtitle_file).clean_all
end
