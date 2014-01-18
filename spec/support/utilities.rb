include ApplicationHelper

def unlock_site path
    visit admin_path
    uncheck("is_locked")
    click_button "Save Settings"
    visit path
    Settings.number_of_dbs = 300
end

def lock_site path
    visit admin_path
    check("is_locked")
    click_button "Save Settings"
    visit path
end

def create_db type, 
        username = Faker::Name.first_name,
        name = Faker::Lorem.word, 
        password = "password", password_conf = "password"
    fill_in "Name", with: name
    choose type
    fill_in "Username", with: username
    fill_in "Password", with: password
    fill_in "Confirm Password", with: password_conf
    click_button "Submit"
end

