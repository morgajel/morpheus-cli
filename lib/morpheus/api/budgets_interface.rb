require 'morpheus/api/api_client'

class Morpheus::BudgetsInterface < Morpheus::APIClient
  def initialize(access_token, refresh_token,expires_at = nil, base_url=nil) 
    @access_token = access_token
    @refresh_token = refresh_token
    @base_url = base_url
    @expires_at = expires_at
  end

  def get(id, params={})
    raise "#{self.class}.get() passed a blank name!" if id.to_s == ''
    url = "#{@base_url}/api/budgets/#{id}"
    headers = { params: params, authorization: "Bearer #{@access_token}" }
    opts = {method: :get, url: url, headers: headers}
    execute(opts)
  end

  def list(params={})
    url = "#{@base_url}/api/budgets"
    headers = { params: params, authorization: "Bearer #{@access_token}" }
    opts = {method: :get, url: url, headers: headers}
    execute(opts)
  end

  def create(payload)
    url = "#{@base_url}/api/budgets"
    headers = { :authorization => "Bearer #{@access_token}", 'Content-Type' => 'application/json' }
    opts = {method: :post, url: url, headers: headers, payload: payload.to_json}
    execute(opts)
  end

  def update(id, payload)
    url = "#{@base_url}/api/budgets/#{id}"
    headers = { :authorization => "Bearer #{@access_token}", 'Content-Type' => 'application/json' }
    opts = {method: :put, url: url, headers: headers, payload: payload.to_json}
    execute(opts)
  end

  def destroy(id, params={})
    url = "#{@base_url}/api/budgets/#{id}"
    headers = { params: params, authorization: "Bearer #{@access_token}" }
    opts = {method: :delete, url: url, headers: headers}
    execute(opts)
  end

  def list_types(params={})
    url = "#{@base_url}/api/budget-types"
    headers = { params: params, authorization: "Bearer #{@access_token}" }
    opts = {method: :get, url: url, headers: headers}
    execute(opts)
  end

end
