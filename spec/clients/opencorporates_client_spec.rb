require 'rails_helper'

RSpec.describe OpencorporatesClient do
  let(:api_token) { 'api_token_xxx' }

  subject { OpencorporatesClient.new(api_token: api_token) }

  describe '#get_jurisdiction_code' do
    before do
      url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/jurisdictions/match"
      @stub = stub_request(:get, url).with(query: "q=United+Kingdom&api_token=#{api_token}")
    end

    it 'returns the jurisdiction code matching the given text' do
      @stub.to_return(body: %({"results":{"jurisdiction":{"code":"gb"}}}))

      expect(subject.get_jurisdiction_code('United Kingdom')).to eq('gb')
    end

    it 'returns nil if the jurisdiction is not matched' do
      @stub.to_return(body: %({"results":{"jurisdiction":{}}}))

      expect(subject.get_jurisdiction_code('United Kingdom')).to be_nil
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*United Kingdom/)
        subject.get_jurisdiction_code('United Kingdom')
      end

      it 'returns nil' do
        expect(subject.get_jurisdiction_code('United Kingdom')).to be_nil
      end
    end
  end

  describe '#get_company' do
    before do
      @url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/gb/01234567"

      @body = %({"results":{"company":{"name":"EXAMPLE LIMITED"}}})

      @stub = stub_request(:get, @url).with(query: "sparse=true&api_token=#{api_token}")
    end

    it 'returns company data for the given jurisdiction_code and company_number' do
      @stub.to_return(body: @body)

      expect(subject.get_company('gb', '01234567')).to eq(name: 'EXAMPLE LIMITED')
    end

    it 'returns nil if the company cannot be found' do
      @stub.to_return(status: 404)

      expect(subject.get_company('gb', '01234567')).to be_nil
    end

    context 'when called with sparse: false' do
      before do
        stub_request(:get, @url).with(query: "api_token=#{api_token}").to_return(body: @body)
      end

      it 'calls the endpoint without the sparse parameter' do
        subject.get_company('gb', '01234567', sparse: false)
      end
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*gb.*01234567/)
        subject.get_company('gb', '01234567')
      end

      it 'returns nil' do
        expect(subject.get_company('gb', '01234567')).to be_nil
      end
    end
  end

  describe '#search_companies' do
    before do
      url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/search"

      query = {
        q: '01234567',
        jurisdiction_code: 'gb',
        fields: 'company_number',
        order: 'score',
        api_token: api_token
      }

      @stub = stub_request(:get, url).with(query: query)
    end

    it 'returns an array of results for the given jurisdiction_code and query' do
      @stub.to_return(body: %({"results":{"companies":[{"company":{"name":"EXAMPLE LIMITED"}}]}}))

      results = subject.search_companies('gb', '01234567')

      expect(results).to be_an(Array)
      expect(results.size).to eq(1)
      expect(results.first).to be_a(Hash)
      expect(results.first.fetch(:company).fetch(:name)).to eq('EXAMPLE LIMITED')
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*01234567.*gb/)
        subject.search_companies('gb', '01234567')
      end

      it 'returns empty array' do
        expect(subject.search_companies('gb', '01234567')).to eq([])
      end
    end
  end
end
