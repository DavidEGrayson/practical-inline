require 'rspec'
require_relative 'spec_helper'

describe 'oracle' do
  it 'has not changed since we last verified it was correct' do
    behavior_hash = Digest::SHA256.new
    minimal = false
    cases = generate_test_cases(minimal)
    case_count = cases.count
    expect(cases.count).to eq 286720
    cases.each do |specs|
      behavior = InliningOracle.inline_behavior(*specs)
      behavior_hash.update(Marshal.dump(behavior))
    end
    expect(behavior_hash.hexdigest).to eq \
      '6b4a4403ffaf34f5c77fcd10ed4e9637fedc367b2af78bf4a8c9debfb0dbb2e9'
  end
end
