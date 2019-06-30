#! /bin/bash
sudo yum update -y

#install AWSCLI
sudo yum install -y awscli

#install and configure nginx
sudo yum install epel-release -y
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
chmod -R og+rx /var/log/nginx /var/log/messages

#install and configure fluentD
curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent3.sh | sh
sudo -u td-agent IP="$(curl http://169.254.169.254/latest/meta-data/public-ipv4)"
sudo td-agent-gem install fluent-plugin-kinesis
sudo echo '#source section
<source>
  @type tail
  path /var/log/nginx/access.log
  pos_file /var/log/td-agent/nginx.access_log.pos
  <parse>
    @type nginx
  </parse>
  tag nginx
</source>

<source>
  @type tail
  path /var/log/messages
  pos_file /var/log/td-agent/messages.pos
  read_from_head true
  <parse>
    @type none
  </parse>
  tag messages
</source>

#match section

<match nginx>
  @type kinesis_firehose
  region us-east-1
  delivery_stream_name PersepolisCollector
</match>

<match messages>
  @type kinesis_firehose
  region us-east-1
  delivery_stream_name PersepolisCollector
</match>

#filter section

<filter **>
  @type record_modifier
    <record>
      hostname "#{Socket.gethostname}"
      tag ${tag}
      timestamp ${Time.at(time).to_s}
      ip "#{ENV['"'"'FOO'"'"']}"
    </record>
</filter>

#defaults

<match td.*.*>
  @type tdlog
  @id output_td
  apikey YOUR_API_KEY

  auto_create_table
  <buffer>
    @type file
    path /var/log/td-agent/buffer/td
  </buffer>

  <secondary>
    @type file
    path /var/log/td-agent/failed_records
  </secondary>
</match>

<match debug.**>
  @type stdout
  @id output_stdout
</match>

<source>
  @type debug_agent
  @id input_debug_agent
  bind 127.0.0.1
  port 24230
</source>' | sudo tee /etc/td-agent/td-agent.conf
sudo systemctl start td-agent
sudo systemctl enable td-agent