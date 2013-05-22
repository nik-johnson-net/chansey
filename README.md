Chansey
=======

Chansey is a distributed systen to automatically perform actions upon receiving arbitrary events. It is both a learning exercise in program design and a useful utility to the author.

Goals
-----

* Clean, commented source code.
* Able to generate internal events from anything.
* Quickly and easily write plugins to perform actions after receiving events
* Allow plugins to interact with service modules via RPC

Design
------

Chansey consists of three component classes:

  1. Service modules
  2. Plugins
  3. Message Queue
  
### Service Modules

The service modules are programs which create internal events from outside events. Service modules may also implement an API so they may be controlled by plugins.

### Plugins

Plugins are based upon layers of abstraction to ease plugin writing. The ruby plugin system is written to include the use of Fibers to give a synchronous API on top of the asynchronous EventMachine reactor. Mixins are also written to add convenience functions for certain services, such as IRC. This way a single plugin can easily interact with any number of services.

### Message Queue

RabbitMQ is the glue which holds everything together and the beating heart which makes it run. Every single bit of information which passes between processes is a message passed through RabbitMQ with specific routing keys. RabbitMQ takes care of getting information where it needs to go and makes the distributed nature of the system much easier to implement.

### Message Types

The source code shows the format for events. There are three types of message:

1. event
2. cmd
3. cmdrply

*event* is used for new events, *cmd* is used for RPC calls, and *cmdrply* is used for RPC replies.

Usage
--------

If you have to ask, you shouldn't. Chansey is meant to be a learning tool, not a public application. I use runit to daemonize and control all the pieces which make up my incarnation of Chansey.

By convention alone, service modules are run by the executable in the root of its source code directory. For example, the IRC module is loaded by running `ruby ./irc/irc.rb`

The ruby plugins are loaded by calling `ruby-plugin-wrapper.rb <plugin file>`.
