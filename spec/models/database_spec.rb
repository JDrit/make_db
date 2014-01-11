require 'spec_helper'

describe Database do
    before do
        @database = Database.new(name: "new db", username: "user", db_type: 1, uid_number: 10387)
    end

    subject { @database }

    it { should respond_to(:name) }
    it { should respond_to(:username) }
    it { should respond_to(:db_type) }
    it { should respond_to(:uid_number) }

    describe "when name is not present" do
        before { @database.name = "  " }
        it { should_not be_valid }
    end

    describe "when username is not present" do
        before { @database.username = "  " }
        it { should_not be_valid }
    end

    describe "when db type is not valid" do
        before { @database.db_type = -1 }
        it { should_not be_valid }
    end

    describe "when uid number is not valid" do
        before { @database.uid_number = -1 }
        it { should_not be_valid }
    end

    describe "when name is too long" do
        before { @database.name = "a" * 256 }
        it { should_not be_valid }
    end

    describe "when username is too long" do
        before { @database.username = "a" * 256 }
        it { should_not be_valid }
    end

end
