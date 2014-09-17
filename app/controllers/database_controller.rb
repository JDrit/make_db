require 'pg'
require 'net/ldap'

class DatabaseController < ApplicationController
    before_action do |c| 
        @uid = request.env['WEBAUTH_USER']
        @entry_uuid = request.env['WEBAUTH_LDAP_ENTRYUUID']
        @admin = true
    end
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
            Rails.logger.info "#{@uid} updated settings to #{params}"
        else
            Rails.logger.info "#{@uid} failed updating settings to #{params}"
        end
        redirect_to admin_path
    end

    def create
        if validate? 
            begin
                result = (@database.db_type == 1) ? create_mysql : create_psql
                if result == true
                    flash[:success] = "Database and user successfully created"
                    @database.save
                else
                    flash[:error] = result
                end
            rescue Exception => e
                Rails.logger.error "Error trying to create database #{@database.name}, #{e}"
                flash[:error] = "Fatal error creating database"
            end
        else
            @is_admin = is_admin?
        end
        redirect_to root_path
    end

    private

        def is_number?(i)
            true if Integer(i) rescue false
        end
    
        # Only allows RTPs to view the admin page
        def only_rtp
            if !@admin
                flash[:error] = "Go away, you're not an RTP"
                Rails.logger.info "#{@uid} tried to access an admin page"
                redirect_to root_path
            end
        end
        
        # Validates user input using the model validatators and custom validators
        # p = the params to validate with
        # returns true if the data is valid, false otherwise
        def validate?
            p = params.require(:database)
            p[:uid_number] = @entry_uuid
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
                Rails.logger.info "#{@uid} tried to create a datbase while the site is locked"
                return false
            end

            if Database.where(uid_number: p[:uid_number]).count >= Settings.number_of_dbs
                flash.now[:error] = "You have reached your max number of databases (#{Settings.number_of_dbs})"
                Rails.logger.info "#{@uid} tried to create another database when they have already hit the limit of #{Settings.number_of_dbs}"
                return false
            end

            result = @database.valid?
            Rails.logger.info "#{@uid} tried creating a database that had the following errors, #{@database.errors.to_a}" if !result
            return result
        end
   
        # Gets the actual names from the list of uid numbers to display to the user
        # uid_numbers = list of uid numbers
        # returns a hashmap of the keys being uid_numbers and the values being their cn
        def get_names uid_numbers
            #TODO switch to use entry uuids
            names = Hash.new
            if uid_numbers.length == 0
                return names
            end
            ldap = Net::LDAP.new(host: Global.ldap.host, 
                                 port: Global.ldap.port,
                                 encryption: :simple_tls,
                                 auth: {
                                    method: :simple,
                                    username: Global.ldap.username,
                                    password: Global.ldap.password
                                 })
            filter = "(|"
            uid_numbers.each { |num| filter += "(uidNumber=#{num})" }
            filter += ")"
            
            treebase = "ou=Users,dc=csh,dc=rit,dc=edu"
            attributes = ["uidNumber", "cn"]
            ldap.open do |ldap|
                ldap.search(base: treebase, filter: filter, attributes: attributes) do  |entry|
                    names[entry.uidNumber[0].to_i] = entry.cn[0]
                end
            end
            return names
        end

        # Creates a postgreSQL database and user
        # returns true if the database and user was created successfully,
        #   an error message if there was a problem
        def create_psql
            error_msg = ""
            conn = PGconn.connect(host: Global.db_auth.psql.host, 
                                  user: Global.db_auth.psql.username,
                                  password: Global.db_auth.psql.password, 
                                  dbname: Global.db_auth.psql.dbname)
            result = conn.exec("SELECT usename FROM pg_user WHERE usename = '#{@database.username}'");
            if result.ntuples != 0
                error_msg = "Username is already in use"
            end
            result = conn.exec("SELECT datname FROM pg_database WHERE datname = '#{@database.name}'");
            if result.ntuples != 0
                if error_msg != ""
                    error_msg += " and the database name is already in use"
                else
                    error_msg = "The database name is already in use"
                end
            end

            if error_msg == ""
                conn.exec("CREATE USER #{@database.username} WITH PASSWORD '#{@database.password}'")
                conn.exec("CREATE DATABASE #{@database.name} OWNER #{@database.username}")
                Rails.logger.info "Created postgres database #{@database.name} for user #{@database.username}, uid: #{@uid}"
                conn.close
                return true
            else
                Rails.logger.info "Failed at creating postgres database #{@database.name} for user #{@database.username}, uid: #{@uid}, error: #{error_msg}"
                connc.close
                return error_msg
            end
        end

        # Creates a mySQL database for the given user
        # It checks to make sure that the username and database name have not
        # be taken and then creates both and deals with permission
        # returns true if the database was created successfully, an error 
        # message otherwise
        def create_mysql
            error_msg = ""
            conn = Mysql2::Client.new(host: Global.db_auth.mysql.host,
                                      username: Global.db_auth.mysql.username,
                                      password: Global.db_auth.mysql.password)
            result = conn.query("SELECT User FROM mysql.user where User = '#{@database.username}'").to_a
            if result.length != 0
                error_msg = "Username is already in use"
            end
            result = conn.query("SHOW DATABASES like '#{@database.name}'").to_a
            if result.length != 0
                if error_msg != "" 
                    error_msg += " and the database name is already in use"
                else
                    error_msg = "The database name is already in use"
                end
            end

            if error_msg != ""
                conn.query("CREATE DATABASE #{@database.name}");
                conn.query("GRANT ALL PRIVILEGES ON #{@database.name}.* TO '#{@database.username}' IDENTIFIED BY '#{@database.password}'")
                Rails.logger.info "Created mysql database #{@database.name} for user #{@database.username}, uid: #{@uid}"
                conn.close
                return true
            else
                Rails.logger.info "Failed at creating mysql database #{@database.name} for user #{@database.username}, uid: #{@uid}, error: #{error_msg}"
                conn.close
                return error_msg
            end
        end
end
