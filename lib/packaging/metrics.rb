module Pkg::Metrics
  module_function

  require "google/apis/sheets_v4"
  require "googleauth"
  require "googleauth/stores/file_token_store"

  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize_google_sheets
    oob_uri = "urn:ietf:wg:oauth:2.0:oob".freeze
    credentials_path = ENV['CREDENTIALS_PATH'] || File.expand_path('credentials.json')
    fail "Error: Could not read credentials file at #{credentials_path}. Set CREDENTIALS_PATH to override the default 'credentials.json'." unless File.readable? credentials_path
    # The file token.yaml stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    token_path = ENV['TOKEN_PATH'] || File.expand_path('token.yaml')
    scope = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

    client_id = Google::Auth::ClientId.from_file credentials_path
    token_store = Google::Auth::Stores::FileTokenStore.new file: token_path
    authorizer = Google::Auth::UserAuthorizer.new client_id, scope, token_store
    user_id = "default"
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: oob_uri
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: oob_uri
      )
    end
    credentials
  end

  def add_new_row_values(spreadsheet_id, range, values)
    # Initialize the API
    service = Google::Apis::SheetsV4::SheetsService.new
    service.authorization = authorize_google_sheets

    value_range_object = Google::Apis::SheetsV4::ValueRange.new(values: values)
    service.append_spreadsheet_value(spreadsheet_id, range, value_range_object, value_input_option: 'USER_ENTERED', insert_data_option: 'INSERT_ROWS', include_values_in_response: true)
  end

  def update_release_spreadsheet
    # This is Molly's test spreadsheet for now; will update once all testing has been done
    spreadsheet_id = '1Kvz3lJ_xymk-H4DsyAApOeT6NDjSArH7KYukWegx9-A'
    range = 'Sheet1'
    values = [[Pkg::Util::Date.today, Pkg::Config.project, Pkg::Config.ref, 'y']]

    puts "Adding #{Pkg::Config.project} #{Pkg::Config.ref} to release spreadsheet . . ."
    add_new_row_values(spreadsheet_id, range, values)
  end
end
