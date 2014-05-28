require 'spec_helper'

# Test coverage for #confirm_tag has been omitted due to it basically being
# little more than a small wrapper around #ask_yes_or_no

describe "Pkg::Util::Prompt" do
  let(:affirmatives)  { %w[yes YES y Y] }
  let(:negatives)     { %w[no NO n N] }
  let(:jibberish)     { "ye olde ham hocks" }

  describe "#ask_yes_or_no" do
    # This is the prompt that
    let(:prompt) { "yes or no? > " }
    it "displays a prompt on STDOUT" do
      fake_stdin(affirmatives.shuffle.first) do
        printed = capture_stdout do
          Pkg::Util::Prompt.ask_yes_or_no
        end
        printed.should eq("#{prompt}")
      end
    end

    it "repeats the prompt on invalid answers" do
      fake_stdin(jibberish, affirmatives.shuffle.first) do
        printed = capture_stdout do
          Pkg::Util::Prompt.ask_yes_or_no
        end
        printed.should eq(%Q[#{prompt}"#{jibberish}" is invalid. Please say yes or no.\n#{prompt}])
      end
    end

    it "understands common variations of yes or no" do
      affirmatives.each do |answer|
        fake_stdin(answer) do
          capture_stdout do
            Pkg::Util::Prompt.ask_yes_or_no.should be_true
          end
        end
      end

      negatives.each do |answer|
        fake_stdin(answer) do
          capture_stdout do
            Pkg::Util::Prompt.ask_yes_or_no.should be_false
          end
        end
      end
    end
  end

  describe "#confirm_ship" do
    let(:stubs)  { ["this", "that", "the other one", "and those right there"] }

    it "accepts a list of files, repeats them correctly" do
      fake_stdin(negatives.shuffle.first) do
        printed = capture_stdout do
          Pkg::Util::Prompt.confirm_ship(stubs)
        end
        printed.include? stubs.join "\n\t"
      end
    end

    it "returns false if you say no" do
      fake_stdin(negatives.shuffle.first) do
        capture_stdout do
          Pkg::Util::Prompt.confirm_ship(stubs).should be_false
        end
      end
    end

    it "returns true if you say yes" do
      fake_stdin(affirmatives.shuffle.first) do
        capture_stdout do
          Pkg::Util::Prompt.confirm_ship(stubs).should be_true
        end
      end
    end
  end
end
