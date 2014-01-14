require 'spec_helper'

describe "DatabasePages" do
  
    subject { page }

    describe "Index Page" do
        before { visit root_path }
        it { should have_content("Make Database") }
    end

end
