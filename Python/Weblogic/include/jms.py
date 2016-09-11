# Utility to help managing Weblogic JMS resources
#
# @author Muhammad Ichsan <ichsan.ichsan@bt.com>
# @date 2016-08-19T0948Z0080
#

import wlstModule as wl
import re

# Do the right thing with boolean values for all known Python versions.
try:
  True, False
except NameError:
  (True, False) = (1, 0)

# Read https://rhpatrickblog.wordpress.com/2015/10/16/wlst-in-fusion-middleware-12-2-1/
DEFAULT_MODULE_NAME = 'NMDBJMSModule'

def lookup_server_instance(instance_name):
  instance_bean = wl.getMBean('/Servers/' + instance_name)

  if instance_bean == None:
    raise LookupError("The target server instance doesn't exist: " + instance_name)

  return instance_bean


def lookup_bridge_destination(name):
  instance_bean = wl.getMBean('/JMSBridgeDestinations/' + name)

  if instance_bean == None:
    raise LookupError("The bridge destination doesn't exist: " + name)

  return instance_bean


def create_server(server_instance_name, jms_server_name):
  wl.cd('/')
  wl.cmo.createJMSServer(jms_server_name)

  wl.cd('/JMSServers/' + jms_server_name)
  #cmo.setPersistentStore(None)
  wl.cmo.addTarget(lookup_server_instance(server_instance_name))


def create_module(server_instance_name, jms_module_name):
  wl.cd('/')
  wl.cmo.createJMSSystemResource(jms_module_name)

  wl.cd('/JMSSystemResources/' + jms_module_name)
  wl.cmo.addTarget(lookup_server_instance(server_instance_name))


def create_subdeployment(jms_module_name, jms_server_name, jms_subdeployment):
  wl.cd('/JMSSystemResources/' + jms_module_name)
  wl.cmo.createSubDeployment(jms_subdeployment)

  jms_server = wl.getMBean('/JMSServers/' + jms_server_name)
  if (jms_server == None):
    raise LookupError("The JMS server doesn't exist")

  wl.cd('/JMSSystemResources/' + jms_module_name + '/SubDeployments/' +
    jms_subdeployment)
  wl.cmo.addTarget(jms_server)


def create_jms_factory(jms_conn_factory_name, jndi_name, jms_module_name =
  DEFAULT_MODULE_NAME):
  wl.cd('/')
  wl.cd('/JMSSystemResources/' + jms_module_name + '/JMSResource/' +
    jms_module_name)
  wl.cmo.createConnectionFactory(jms_conn_factory_name)

  wl.cd('/JMSSystemResources/' + jms_module_name + '/JMSResource/' +
    jms_module_name + '/ConnectionFactories/' + jms_conn_factory_name)
  wl.cmo.setJNDIName(jndi_name)
  wl.cmo.setDefaultTargetingEnabled(True)


def create_queue(jms_queue_name, jms_queue_jndi, jms_module_name =
  DEFAULT_MODULE_NAME, jms_subdeployment = None):
  if (jms_subdeployment == None):
    jms_subdeployment = jms_module_name

  print "Entering module", jms_module_name
  wl.cd('/JMSSystemResources/' + jms_module_name)

  wl.cd('/JMSSystemResources/' + jms_module_name + '/JMSResource/' +
    jms_module_name)
  wl.cmo.createQueue(jms_queue_name)

  wl.cd('/JMSSystemResources/' + jms_module_name + '/JMSResource/' +
    jms_module_name + '/Queues/' + jms_queue_name)
  wl.set('JNDIName', jms_queue_jndi)
  wl.set('SubDeploymentName', jms_subdeployment)


def create_bridge_local_destination(connection_factory_jndi, destination_jndi,
  connection_url = 't3://localhost:6001', bridge_destination_name = None):
  if (bridge_destination_name == None):
    bridge_destination_name = 'Local_' + destination_jndi

  wl.cd('/')
  wl.cmo.createJMSBridgeDestination(bridge_destination_name)

  wl.cd('/JMSBridgeDestinations/' + bridge_destination_name)
  wl.set('ConnectionURL', connection_url)

  wl.set('AdapterJNDIName', 'eis.jms.WLSConnectionFactoryJNDIXA')
  wl.set('ConnectionFactoryJNDIName', connection_factory_jndi)
  wl.set('DestinationJNDIName', destination_jndi)

  return bridge_destination_name


def create_bridge_remote_destination(connection_factory_jndi, destination_jndi,
  connection_url, username = None, password = None, bridge_destination_name = None):
  if (bridge_destination_name == None):
    bridge_destination_name = 'Remote_' + destination_jndi

  wl.cd('/')
  wl.cmo.createJMSBridgeDestination(bridge_destination_name)

  wl.cd('/JMSBridgeDestinations/' + bridge_destination_name)
  wl.set('ConnectionURL', connection_url)

  if username != None:
    wl.set('UserName', username)
  if password != None:
    if password.startswith('enc:'):
      splits = password.replace('enc:', '').split(',')
      # password = wl.encrypt(splits[0], splits[1])
      password = splits[0]
    # wl.set('UserPassword', password) # TODO(ichsan): Fix this because it failed to run

  wl.set('AdapterJNDIName', 'eis.jms.WLSConnectionFactoryJNDIXA')
  wl.set('ConnectionFactoryJNDIName', connection_factory_jndi)
  wl.set('DestinationJNDIName', destination_jndi)

  return bridge_destination_name


def create_bridge(source_bridge_destination, target_bridge_destination, server_instance_name, bridge_name = None):
  if bridge_name == None:
    bridge_name = next_simple_bridge_name()

  wl.cd('/')
  wl.cmo.createMessagingBridge(bridge_name)

  wl.cd('/Deployments/' + bridge_name)
  wl.cmo.addTarget(lookup_server_instance(server_instance_name))
  wl.cmo.setSourceDestination(lookup_bridge_destination(source_bridge_destination))
  wl.cmo.setTargetDestination(lookup_bridge_destination(target_bridge_destination))

  # wl.set('Selector', '')
  # wl.set('QualityOfService', 'Exactly-once')
  # wl.set('QOSDegradationAllowed', 'true')
  # wl.set('IdleTimeMaximum', '60')
  # wl.set('AsyncEnabled', 'true')
  # wl.set('DurabilityEnabled', 'true')
  # wl.set('PreserveMsgProperty', 'false')
  wl.set('Started', 'true')

  return bridge_name


# Return something like Bridge1, Bridge2, and so on.
def next_simple_bridge_name():
  wl.cd('/Deployments/')
  i = 1

  while True:
    name = 'Bridge' + str(i)
    matches = filter(lambda v, name = name: re.compile("^" + name + "$").match(v), __sls())
    if len(matches) == 0:
      return name
    i += 1


def __sls():
  wl.redirect('/dev/null', 'false')
  result = wl.ls(returnMap = 'true')
  wl.redirect('/dev/null', 'true')
  return result
