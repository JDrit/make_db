require 'pg'
class DatabaseController < ApplicationController
    before_action :only_rtp, only: [:admin]

    def index
        @database = Database.new
        @is_admin = is_admin?
    end

    def admin
        #@databases = Database.all
        @databases = Database.paginate(page: params[:page])
        @names = get_names Database.all.collect(&:uid_number)
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
        def only_rtp
            if is_admin?

            else
                flash[:error] = "Go away, you're not an RTP"
                redirect_to "/"
            end
        end

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

        def is_admin?
            uid = "jeid"
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
            ldap.search(:base => treebase, :filter => filter) do |entry|
                entry[:member].each do |dn|
                    if dn.include? uid
                        return true
                    end
                end
            end
            return false
        end

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
            puts filter
            ldap.search(:base => treebase, :filter => filter) do  |entry|
                names[entry.uidNumber[0].to_i] = entry.cn[0]
            end
            puts names
            return names
        end

        def db_params
            p = params.require(:database)
            puts p
            p[:uid_number] = 10385
            if p[:db_type] == "mysql"
                p[:db_type] = 1
            elsif p[:db_type] == "pg"
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
