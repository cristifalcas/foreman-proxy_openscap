#
# Copyright (c) 2014 Red Hat Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 3 (GPLv3). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv3
# along with this software; if not, see http://www.gnu.org/licenses/gpl.txt
#

require 'digest'
require 'fileutils'
require 'proxy/error'

module Proxy::OpenSCAP
  def self.common_name(request)
    client_cert = request.env['SSL_CLIENT_CERT']
    raise Proxy::Error::Unauthorized, "Client certificate required!" if client_cert.to_s.empty?

    begin
      client_cert = OpenSSL::X509::Certificate.new(client_cert)
    rescue OpenSSL::OpenSSLError => e
      raise Proxy::Error::Unauthorized, e.message
    end
    cn = client_cert.subject.to_a.detect { |name, value| name == 'CN' }
    cn = cn[1] unless cn.nil?
    raise Proxy::Error::Unauthorized, "Common Name not found in the certificate" unless cn
    return cn
  end

  def self.spool_arf_dir(common_name, policy_name, date)
    validate_policy_name policy_name
    validate_date date
    dir = Proxy::OpenSCAP::Plugin.settings.spooldir + "/arf/#{common_name}/#{policy_name}/#{date}/"
    begin
      FileUtils.mkdir_p dir
    rescue StandardError => e
      logger.error "Could not create '#{dir}' directory: #{e.message}"
      raise e
    end
    dir
  end

  def self.store_arf(spool_arf_dir, data)
    filename = Digest::SHA256.hexdigest data
    target_path = spool_arf_dir + filename
    File.open(target_path,'w') { |f| f.write(data) }
    return target_path
  end

  private
  def self.validate_policy_name name
    unless /[\w-]+/ =~ name
      raise Proxy::Error::BadRequest, "Malformed policy name"
    end
  end

  def self.validate_date date
    begin
      Date.strptime(date, '%Y-%m-%d')
    rescue
      raise Proxy::Error::BadRequest, "Malformed date"
    end
  end
end
