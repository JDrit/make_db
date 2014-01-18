require 'spec_helper'

describe "DatabasePages" do
  
    subject { page }

    describe "Index Page" do
        before do 
            visit root_path
        end
        it { should have_content("Make Database") }
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
                end

                it { should have_content("Settings successfully updated") }
            end
        end
    end
end
