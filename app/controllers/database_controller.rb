require 'pg'
class DatabaseController < ApplicationController
    before_action :only_rtp, only: [:admin, :update_settings]

    def index
        if Settings.is_locked
            flash[:error] = "Site is locked"
        end
 
        @database = Database.new
        @is_admin = is_admin?
    end

    def admin
        if !(is_number? params[:page]) || params[:page].to_i <= 0
            params[:page] = 1
        end
        @databases = Database.paginate(page: params[:page])
        # the hashmap of the uid numbers to members' usernames
        @names = get_names (Set.new @databases.collect(&:uid_number))
        @is_admin = true
        @number_allowed = Settings.number_of_dbs
        @is_locked = Settings.is_locked
    end

    def update_settings
        success = true
        if is_number?(params[:number_of_dbs]) && params[:number_of_dbs].to_i > 0
            Settings.number_of_dbs = params[:number_of_dbs].to_i
        else
            flash[:error] = "Number of databases is invalid"
            success = false
        end
        if !params[:is_locked].nil?
            Settings.is_locked = true
        else
            Settings.is_locked = false
        end
        if success
            flash[:success] = "Settings successfully updated"
        end
        redirect_to admin_path
    end

    def create
        if validate? 
            if @database.db_type == 1 # mysql
                result = create_mysql
            else # postgresql
                result = create_psql
            end
            if !(result.is_a? String)
                flash[:success] = "Database and user successfully created"
                @database.save
                redirect_to root_path
            else
                flash[:error] = result
                redirect_to root_path
            end
        else
            @is_admin = is_admin?
            render 'index'
        end
    end

    private

        def is_number?(i)
            true if Integer(i) rescue false
        end
    
        # Only allows RTPs to view the admin page
        def only_rtp
            if !is_admin?
                flash[:error] = "Go away, you're not an RTP"
                redirect_to root_path
            end
        end
        
        # Validates user input using the model validatators and custom validators
        # p = the params to validate with
        # returns true if the data is valid, false otherwise
        def validate?
            p = params.require(:database)
            p[:uid_number] = get_uid_number('jd')
            #p[:uid_number] = get_uid_number(response.headers['WEBAUTH_USER'])
            if p[:db_type] == "mysql"
                p[:db_type] = 1
            elsif p[:db_type] == "pg"
                p[:db_type] = 2
            else
                return false
            end

            @database = Database.new(name: p[:name], username: p[:username], db_type: p[:db_type],
                                     uid_number: p[:uid_number], password: p[:password], 
                                     password_confirmation: p[:password_confirmation])
            if Settings.is_locked
                flash.now[:error] = "The Site has been locked by an RTP, no new databases can be created"
                return false
            end

            if Database.where(uid_number: p[:uid_number]).count >= Settings.number_of_dbs
                flash.now[:error] = "You have reached your max number of databases (#{Settings.number_of_dbs})"
                return false
            end

            return @database.valid?
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
                ldap.search(:base => treebase, :filter => filter, 
                            :attributes => ["member"]) do |entry|
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
            if uid_numbers.length == 0
                return names
            end
            ldap = Net::LDAP.new :host => Global.ldap.host,
                :port => Global.ldap.port,
                :encryption => :simple_tls,
                :auth => {
                    :method => :simple,
                    :username => Global.ldap.username,
                    :password => Global.ldap.password
                }
            filter = "(|"
            uid_numbers.each { |num| filter += "(uidNumber=#{num})" }
            filter += ")"
            
            treebase = "ou=Users,dc=csh,dc=rit,dc=edu"
            attributes = ["uidNumber", "cn"]
            ldap.open do |ldap|
                ldap.search(:base => treebase, :filter => filter, 
                            :attributes => attributes) do  |entry|
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
                result = ldap.search(:base => treebase, :filter => filter, 
                                     :attributes => ["uidNumber"])[0]
            end
            return result.uidNumber[0].to_i
        end

        # Creates a postgreSQL database and user
        # returns true if the database and user was created successfully,
        #   an error message if there was a problem
        def create_psql
            return_val = true
            conn = PGconn.connect(:host => Global.db_auth.psql.host, 
                                  :user => Global.db_auth.psql.username,
                                  :password => Global.db_auth.psql.password, 
                                  :dbname => Global.db_auth.psql.dbname)
            result = conn.exec("SELECT usename FROM pg_user WHERE usename = '#{@database.username}'");
            if result.ntuples != 0
                return_val = "Username is already in use"
            end
            result = conn.exec("SELECT datname FROM pg_database WHERE datname = '#{@database.name}'");
            if result.ntuples != 0
                if return_val.is_a? String
                    return_val += " and the database name is already in use"
                else
                    return_val = "The database name is already in use"
                end
            end

            if !(return_val.is_a? String)
                conn.exec("CREATE USER #{@database.username} WITH PASSWORD '#{@database.password}'")
                conn.exec("CREATE DATABASE #{@database.name} OWNER #{@database.username}")
            end
            return return_val
        end

        # Creates a mySQL database for the given user
        # It checks to make sure that the username and database name have not
        # be taken and then creates both and deals with permission
        # returns true if the database was created successfully, an error 
        # message otherwise
        def create_mysql
            return_val = true
            conn = Mysql2::Client.new(:host => Global.db_auth.mysql.host,
                                       :username => Global.db_auth.mysql.username,
                                       :password => Global.db_auth.mysql.password)
            result = conn.query("SELECT User FROM mysql.user where User = '#{@database.username}'").to_a
            if result.length != 0
                return_val = "Username is already in use"
            end
            result = conn.query("SHOW DATABASES like '#{@database.name}'").to_a
            if result.length != 0
                if return_val.is_a? String
                    return_val += " and the database name is already in use"
                else
                    return_val = "The database name is already in use"
                end
            end

            if !(return_val.is_a? String)
                conn.query("CREATE DATABASE #{@database.name}");
                conn.query("GRANT ALL PRIVILEGES ON #{@database.name}.* TO '#{@database.username}' IDENTIFIED BY '#{@database.password}'")
            end
            conn.close
            return return_val
        end
end
