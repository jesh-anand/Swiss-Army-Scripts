#!/usr/bin/python
#
# As script to help creating a JMS instance
#
# @author Muhammad Ichsan <ichsan.ichsan@bt.com>
#
# Sample usage:
#   /software/bea/wls/10.30/wlserver_10.3/common/bin/wlst.sh include/jms_main.py -l t3://10.54.132.34:61000 -u weblogic -p nmdbcit34 resources.properties
#

import getopt
import sys
import re
from weblogic.descriptor import BeanAlreadyExistsException
import include.jms as nmjms
import traceback

ERROR_PREPROC=1
ERROR_EXIST=2
ERROR_TARGET_NON_EXISTENT=3
ERROR_ANY=4
UNDEFINED=-1984

def load_properties(dfile):
  d = {}
  fp = open(dfile, 'r')

  try:
    for line in fp.readlines():
      if line.strip() and not line.startswith('#'):
        tokens = line.rstrip().split('=')
        d[tokens[0]] = '='.join(tokens[1:])

  finally:
    fp.close()

  return d


def attr(dictionary, key, default_value = UNDEFINED):
  if key in dictionary.keys():
    value = dictionary[key]
  else:
    if (default_value != UNDEFINED):
      value = default_value
    else:
      raise Exception("Key doesn't exist: " + key)

  if value != None and value.startswith('ref:'):
    ref_key = value.split(':')[1]
    return attr(dictionary, ref_key, default_value)

  return value


def create_jms_servers(props):
  for k in filter(lambda k: re.compile("^jms.server.[0-9]+.name$").match(k), props.keys()):
    try:
      jms_server_name = props[k]
      i = k.split('.')[2]
      server_instance_name = attr(props, 'jms.server.' + i + '.target')

      nmjms.create_server(server_instance_name, jms_server_name)
      print 'JMS Server', jms_server_name, 'created'

    except BeanAlreadyExistsException:
      print 'JMS Server', jms_server_name, "was not created as it's already existed"


def create_jms_modules(props):
  for k in filter(lambda k: re.compile("^jms.module.[0-9]+.name$").match(k), props.keys()):
    try:
      jms_module_name = props[k]
      i = k.split('.')[2]
      server_instance_name = attr(props, 'jms.module.' + i + '.target')

      nmjms.create_module(server_instance_name, jms_module_name)
      print 'JMS Module', jms_module_name, 'created'

    except BeanAlreadyExistsException:
      print 'JMS Module', jms_module_name, "was not created as it's already existed"


def create_jms_subdeployments(props):
  for k in filter(lambda k: re.compile("^jms.subdeployment.[0-9]+.name$").match(k), props.keys()):
    try:
      jms_subdeployment_name = props[k]
      i = k.split('.')[2]
      jms_module_name = attr(props, 'jms.subdeployment.' + i + '.module')
      jms_server_name = attr(props, 'jms.subdeployment.' + i + '.target')

      nmjms.create_subdeployment(jms_module_name, jms_server_name, jms_subdeployment_name)
      print 'JMS Subdeployment', jms_subdeployment_name, 'created'

    except BeanAlreadyExistsException:
      print 'JMS Subdeployment', jms_subdeployment_name, "was not created as it's already existed"


def create_jms_connection_factories(props):
  for k in filter(lambda k: re.compile("^jms.connection_factory.[0-9]+.name$").match(k), props.keys()):
    try:
      jms_conn_factory_name = props[k]
      i = k.split('.')[2]
      jndi_name = attr(props, 'jms.connection_factory.' + i + '.jndi')

      k2 = 'jms.connection_factory.' + i + '.module'
      if k2 in props.keys():
        nmjms.create_jms_factory(jms_conn_factory_name, jndi_name, attr(props, k2))
      else:
        nmjms.create_jms_factory(jms_conn_factory_name, jndi_name)

      print 'JMS Connection Factory', jms_conn_factory_name, 'created'

    except BeanAlreadyExistsException:
      print 'JMS Connection Factory', jms_conn_factory_name, "was not created as it's already existed"


def create_jms_queues(props):
  for k in filter(lambda k: re.compile("^jms.queue.[0-9]+.name$").match(k), props.keys()):
    try:
      jms_queue_name = props[k]
      i = k.split('.')[2]
      jms_queue_jndi = attr(props, 'jms.queue.' + i + '.jndi')

      k2 = 'jms.queue.' + i + '.module'
      if k2 in props.keys():
        jms_module_name = attr(props, k2)
        nmjms.create_queue(jms_queue_name, jms_queue_jndi, jms_module_name, attr(props, 'jms.queue.' + i + '.subdeployment', None))
      else:
        nmjms.create_queue(jms_queue_name, jms_queue_jndi)

      print 'JMS Queue', jms_queue_name, 'created'

    except BeanAlreadyExistsException:
      print 'JMS Queue', jms_queue_name, "was not created as it's already existed"


def create_jms_bridge_local_destinations(props):
  for k in filter(lambda k: re.compile("^jms.bridge_local_dest.[0-9]+.connection_factory_jndi$").match(k), props.keys()):
    try:
      connection_factory_jndi = attr(props, k)
      i = k.split('.')[2]
      destination_jndi = attr(props, 'jms.bridge_local_dest.' + i + '.destination_jndi')
      connection_url = attr(props, 'jms.bridge_local_dest.' + i + '.connection_url', 't3://localhost:6001')
      name = attr(props, 'jms.bridge_local_dest.' + i + '.name', None)

      final_name = nmjms.create_bridge_local_destination(connection_factory_jndi,
        destination_jndi, connection_url, name)
      props['jms.bridge_local_dest.' + i + '.name'] = final_name

      print 'Bridge local destination', final_name, 'created'

    except BeanAlreadyExistsException:
      print 'Bridge local destination', final_name, "was not created as it's already existed"


def create_jms_bridge_remote_destinations(props):
 for k in filter(lambda k: re.compile("^jms.bridge_remote_dest.[0-9]+.connection_factory_jndi$").match(k), props.keys()):
    try:
      connection_factory_jndi = attr(props, k)
      i = k.split('.')[2]
      destination_jndi = attr(props, 'jms.bridge_remote_dest.' + i + '.destination_jndi')
      connection_url = attr(props, 'jms.bridge_remote_dest.' + i + '.connection_url')
      username = attr(props, 'jms.bridge_remote_dest.' + i + '.username', None)
      password = attr(props, 'jms.bridge_remote_dest.' + i + '.password', None)
      name = attr(props, 'jms.bridge_remote_dest.' + i + '.name', None)

      final_name = nmjms.create_bridge_remote_destination(connection_factory_jndi,
        destination_jndi, connection_url, username, password, name)
      props['jms.bridge_remote_dest.' + i + '.name'] = final_name

      print 'Bridge remote destination', final_name, 'created'

      if (password != None):
        print '============>> Please set the password manually'

    except BeanAlreadyExistsException:
      print 'Bridge remote destination', final_name, "was not created as it's already existed"


def create_jms_bridges(props):
  for k in filter(lambda k: re.compile("^jms.bridge.[0-9]+.src_dest$").match(k), props.keys()):
    try:
      src_dest = attr(props, k)
      i = k.split('.')[2]
      target_dest = attr(props, 'jms.bridge.' + i + '.target_dest')
      server_instance_name = attr(props, 'jms.bridge.' + i + '.target')
      name = attr(props, 'jms.bridge.' + i + '.name', None)

      final_name = nmjms.create_bridge(src_dest, target_dest, server_instance_name, name)

      print 'Bridge', final_name, 'created'

    except BeanAlreadyExistsException:
      print 'Bridge', final_name, "was not created as it's already existed"


print "You're using Python", sys.version_info

help_msg = """Usage:
%s [OPTIONS] <resource.properties containing resources to create>
    -l  --url             WLS URL
    -u  --username        WLS username
    -p  --password        WLS password

 e.g. %s -l t3://10.54.132.34:61000 -u weblogic -p nmdbcit34 resources.properties
"""

help_msg = help_msg % (sys.argv[0], sys.argv[0])

try:
  # -h, --url, -u <arg>, -p <arg>
  opts, args = getopt.getopt(sys.argv[1:], "hl:u:p:", ["url=", "username=", "password="])
except getopt.GetoptError:
  print help_msg
  sys.exit(ERROR_PREPROC)


wls_url = ''
wls_username = ''
wls_password = ''

for opt, arg in opts:
  if opt == "-h":
    print help_msg
    sys.exit()
  elif opt in ("-l", "--url"):
    wls_url = arg
  elif opt in ("-u", "--username"):
    wls_username = arg
  elif opt in ("-p", "--password"):
    wls_password = arg

if wls_url == '':
  print 'Missing required URL'
  print help_msg
  sys.exit(ERROR_PREPROC)
if wls_username == '':
  print 'Missing required username'
  print help_msg
  sys.exit(ERROR_PREPROC)
if wls_password == '':
  print 'Missing required password'
  print help_msg
  sys.exit(ERROR_PREPROC)

if len(args) != 1:
  print help_msg
  sys.exit(ERROR_PREPROC)

properties_file = args[0]
props = load_properties(properties_file)

connect(wls_username, wls_password, wls_url)

edit()
startEdit()
cmgr = getConfigManager()

try:
  create_jms_servers(props)
  create_jms_modules(props)
  create_jms_subdeployments(props)

  create_jms_connection_factories(props)
  create_jms_queues(props)

  create_jms_bridge_local_destinations(props)
  create_jms_bridge_remote_destinations(props)
  create_jms_bridges(props)

  # Commit all changes
  activate()
  print "Configuration is done!"

except:
  traceback.print_exc(file=sys.stdout)
  print "Hit unknown error. Undoing edit process."
  cmgr.undo()
  cmgr.cancelEdit()
  sys.exit(ERROR_ANY)

cmgr.purgeCompletedActivationTasks()