FactoryGirl.define do
    factory :database do
        sequence(:username) { |n| "user#{n}" }
        sequence(:name) { |n| "db#{n}" }
        db_type (1..2).to_a.sample                                                                                                                                                                      
        uid_number  (10000..10425).to_a.sample
        password "password"
    end
end
