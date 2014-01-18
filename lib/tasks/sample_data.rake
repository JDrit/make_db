namespace :db do
    desc "Fill database with sample database"
    task populate: :environment do
        60.times do |n|
            username  = Faker::Name.first_name
            name = "example#{n+1}"
            db_type = (1..2).to_a.sample
            uid_number = (10000..10425).to_a.sample
            Database.create!(username: username,
                            name: name,
                            db_type: db_type,
                            uid_number: uid_number)
        end
    end
end
