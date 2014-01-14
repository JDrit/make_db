class Database < ActiveRecord::Base
    validates :name, presence: true, length: { maximum: 16 }, 
        format: { with: /\A[a-z0-9]+$\z/i, 
                  message: "Can only be alphanumeric" } 
    validates :username, presence: true, length: { maximum: 16 },
        format: { with: /\A[a-z0-9]+$\z/i, 
                  message: "Can only be alphanumberic" } 
    validates :db_type, presence: true, inclusion: 1..2
    validates :uid_number, presence: true, :numericality => { :greater_than => 0 }

    default_scope { order('databases.created_at DESC') }

end
