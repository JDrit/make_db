class Database < ActiveRecord::Base
    #attr_accessible :password
    attr_accessor :password
    VALID_REGEX = /\A[a-z][a-z0-9]*$\z/i

    validates :name, presence: true, length: { maximum: 16 }, 
        format: { with: VALID_REGEX, 
                  message: "Can only be alphanumeric" } 
    validates :username, presence: true, length: { maximum: 16 },
        format: { with: VALID_REGEX, 
                  message: "Can only be alphanumberic" } 
    validates :db_type, presence: true, inclusion: 1..2
    validates :uid_number, presence: true, :numericality => { :greater_than => 0 }
    validates :password, presence: true, length: { maximum: 41 },
        format: { with: /\A[a-z0-9]*$\z/i,
                  message: "Can only be alphanumeric" },
        confirmation: true

    default_scope { order('databases.created_at DESC') }

end
