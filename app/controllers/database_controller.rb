require 'pg'
class DatabaseController < ApplicationController
    before_action :only_rtp, only: [:admin]

    def index
        @database = Database.new
        @is_admin = is_admin?
    end

    def admin
        @databases = Database.paginate(page: params[:page])
        @names = get_names (Set.new Database.all.collect(&:uid_number))
        @is_admin = true
    end

    def create
        p = db_params 
        if validate? p
            puts p
            if p[:db_type] == 1
                result = create_mysql p
            else
                result = create_psql p
            end
            if !(result.is_a? String)
                flash[:success] = "Database and user successfully created"
                @database.save
                redirect_to '/'
            else
                flash[:error] = result
                redirect_to '/'
            end
        else
            @is_admin = is_admin?
            render 'index'
        end
    end

    private
        # Only allows RTPs to view the admin page
        def only_rtp
            if !is_admin?
                flash[:error] = "Go away, you're not an RTP"
                redirect_to "/"
            end
        end
        
        # Validates user input using the model validatators and custom validators
        # p = the params to validate with
        # returns true if the data is valid, false otherwise
        def validate? p
            @database = Database.new(name: p[:name], username: p[:username], 
                                 db_type: p[:db_type], 
                                 uid_number: p[:uid_number])
            valid = @database.valid?
            if p[:password].empty? || p[:confirm_password].empty?
                @database.errors.add(:password, "cannot be empty")
                return false
            elsif p[:password] != p[:confirm_password]
                @database.errors.add(:passwords, " need to match")
                return false
            else
                return valid
            end
        end

        # Connects to ldap to make sure that the given user is an RTP
        # returns true if the user is an admin, false otherwise
        def is_admin?
            uid = "jeid"
            result = false
            #uid = response.headers['WEBAUTH_USER']
            ldap = Net::LDAP.new :host => Global.ldap.host,
                :port => Global.ldap.port,
                :encryption => :simple_tls,
                :auth => {
                    :method => :simple,
                    :username => Global.ldap.username,
                    :password => Global.ldap.password
                }
        
            filter = Net::LDAP::Filter.eq("cn", "rtp")
            treebase = "ou=Groups,dc=csh,dc=rit,dc=edu"
            ldap.open do |ldap|
                ldap.search(:base => treebase, :filter => filter, :attributes => ["member"]) do |entry|
                    entry[:member].each do |dn|
                        if dn.include? uid
                            result = true
                            break
                        end
                    end
                end
            end
            return result
        end
    
        # Gets the actual names from the list of uid numbers to display to the user
        # uid_numbers = list of uid numbers
        # returns a hashmap of the keys being uid_numbers and the values being their cn
        def get_names uid_numbers
            names = Hash.new
            ldap = Net::LDAP.new :host => Global.ldap.host,
                :port => Global.ldap.port,
                :encryption => :simple_tls,
                :auth => {
                    :method => :simple,
                    :username => Global.ldap.username,
                    :password => Global.ldap.password
                }
            filter = nil
            uid_numbers.each do |num|
                if filter == nil
                    filter = Net::LDAP::Filter.eq("uidNumber", num.to_s)
                else
                    filter = Net::LDAP::Filter.intersect(filter, Net::LDAP::Filter.eq("uidNumber", num.to_s))
                end
            end
            treebase = "ou=Users,dc=csh,dc=rit,dc=edu"
            ldap.open do |ldap|
                ldap.search(:base => treebase, :filter => filter, :attributes => ["uidNumber", "cn"]) do  |entry|
                    names[entry.uidNumber[0].to_i] = entry.cn[0]
                end
            end
            return names
        end

        # gets the uid number for a given user from their username
        # uid = the user's username
        # returns the uid number for the given user
        def get_uid_number(uid)
            result = nil
            ldap = Net::LDAP.new :host => Global.ldap.host,
                :port => Global.ldap.port,
                :encryption => :simple_tls,
                :auth => {
                    :method => :simple,
                    :username => Global.ldap.username,
                    :password => Global.ldap.password
                }
            treebase = "ou=Users,dc=csh,dc=rit,dc=edu"
            filter = Net::LDAP::Filter.eq("uid", uid)
            ldap.open do |ldap|
                result = ldap.search(:base => treebase, :filter => filter, :attributes => ["uidNumber"])[0]
            end
            return result.uidNumber[0].to_i
        end

        # returns the params of the new database
        def db_params
            p = params.require(:database)
            puts p
            p[:uid_number] = get_uid_number('jd')
            #p[:uid_number] = get_uid_number(response.headers['WEBAUTH_USER'])
            if p[:db_type] == "mysql"
                p[:db_type] = 1
            elsif p[:db_type] == "pg"
                p[:db_type] = 2
            else
                return false
            end
            return p
        end

        # Creates a postgreSQL database and user
        # params = the params for the new database
        # returns true if the database and user was created successfully,
        #   an error message if there was a problem
        def create_psql params
            return_val = true
            conn = PGconn.connect(:host => Global.db_auth.psql.host, 
                                  :user => Global.db_auth.psql.username,
                                  :password => Global.db_auth.psql.password, 
                                  :dbname => Global.db_auth.psql.dbname)
            result = conn.exec("SELECT usename FROM pg_user WHERE usename = '#{params[:username]}'");
            if result.ntuples != 0
                return_val = "Username is already in use"
            end
            result = conn.exec("SELECT datname FROM pg_database WHERE datname = '#{params[:name]}'");
            if result.ntuples != 0
                if return_val.is_a? String
                    return_val += " and the database name is already in use"
                else
                    return_val = "The database name is already in use"
                end
            end

            if !(return_val.is_a? String)
                conn.exec("CREATE USER #{params[:username]} WITH PASSWORD '#{params[:password]}'")
                conn.exec("CREATE DATABASE #{params[:name]} OWNER #{params[:username]}")
            end
            return return_val
        end
end
