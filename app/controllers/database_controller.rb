require 'pg'
class DatabaseController < ApplicationController
    def index
        @database = Database.new
    end

    def create
        p = db_params 
        if validate? p
            result = create_psql p
            if !(result.is_a? String)
                flash[:success] = "Database and user successfully created"
                @database.save
                redirect_to '/'
            else
                flash[:error] = result
                redirect_to '/'
            end
        else
            render 'index'
        end
    end

    private
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

        def db_params
            p = params.require(:database)
            p[:uid_number] = 10387
            if p[:db_type] = "mysql"
                p[:db_type] = 1
            elsif p[:db_type] = "pg"
                p[:db_type] = 2
            else
                return false
            end
            return p
        end

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
            conn.close
            return return_val
        end
end
