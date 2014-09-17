require 'spec_helper'

describe "DatabasePages" do
  
    subject { page }

    describe "Index Page" do
        before do 
            visit root_path
        end
        it { should have_content("Make Database") }

        describe "make valid SQL database" do
            let(:count) { Database.count }
            before do 
                unlock_site root_path
                create_db "mySQL" 
            end

            it { @count == Database.count + 1 }
            it { should have_content("Database and user successfully created") }
            system 'sh /home/jd/Documents/git/make_db/spec/clean_mysql.sh'
        end
        
        describe "make database with all invalid information" do
            let(:count) { Database.count }
            it do 
                create_db "mySQL", name = "qqqqqqqqqqqqqqqqqqqqqqqq", 
                    username = "2fsdafds", password = "", password_cof = "q"
                should { @count == Database.count } # a db row should not have been created
                should have_content("is too long (maximum is 16 characters)")
                should have_content("Can only be alphanumeric")
                should have_content("can't be blank") 
                should have_content("doesn't match Password")
            end
        end

        describe "make database with database name already in use" do
            let(:db_name) { Faker::Lorem.word }
           
            it do 
                unlock_site root_path
                fill_in "Name", with: db_name
                choose "mySQL"
                fill_in "Username", with: Faker::Name.first_name
                fill_in "Password", with: "password"
                fill_in "Confirm Password", with: "password"
                click_button "Submit"
                fill_in "Name", with: db_name
                choose "mySQL"
                fill_in "Username", with: Faker::Name.first_name
                fill_in "Password", with: "password"
                fill_in "Confirm Password", with: "password"
                click_button "Submit"

                system 'sh /home/jd/Documents/git/make_db/spec/clean_mysql.sh'
                should have_content("The database name is already in use")
            end
        end

        describe "make database with username already in use" do
            let(:u_name) { Faker::Name.first_name }

            it do
                unlock_site root_path
                fill_in "Name", with: Faker::Lorem.word
                choose "mySQL"
                fill_in "Username", with: u_name
                fill_in "Password", with: "password"
                fill_in "Confirm Password", with: "password"
                click_button "Submit"
                fill_in "Name", with: Faker::Lorem.word
                choose "mySQL"
                fill_in "Username", with: u_name
                fill_in "Password", with: "password"
                fill_in "Confirm Password", with: "password"
                click_button "Submit"

                should have_content("Username is already in use")
                system 'sh /home/jd/Documents/git/make_db/spec/clean_mysql.sh'
            end
        end

        describe "make database while site is locked" do

        end

        describe "make database when user has already reached their limit" do

        end

    end

    describe "Admin Page" do
        before do
            visit admin_path
        end
        
        describe "pagination" do
            before(:all) {32.times { FactoryGirl.create(:database) }}
            after(:all) { Database.delete_all }
            
            it { should have_selector('ul.pagination') }

            it "should list all the dbs" do
                Database.paginate(page: 1).each do |db|
                    expect(page).to have_content(db.name)
                end
            end
        end

        describe "settings" do
            
            describe "with invalid number of dbs" do
                before do
                    fill_in "number_of_dbs", with: "-1"
                    click_button "Save Settings"
                end
                it { should have_content("Number of databases is invalid") } 
                it { should_not have_field('number_of_dbs', :with => '-1') }
            end

            describe "with valid number of dbs" do
                before do
                    fill_in "number_of_dbs", with: "3"
                    click_button "Save Settings"
                end
                it { should have_content("Settings successfully updated") }
                it { should have_field("number_of_dbs", :with => "3") }
            end

            describe "lock site" do
                before do
                    check("is_locked")
                    click_button "Save Settings"
                    visit root_path
                end
                it { should have_content("Site is locked") }
            end
        end
    end
end
