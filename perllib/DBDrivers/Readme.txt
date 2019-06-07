===== DBDriver =====

Note that there are a couple of Drivers that could be further separated to
have even better OO, but I started to get bogged down in multiple inheritence
problems so I left them as is for now. For instance, separating PipedExecutable
support from the 70HyphenFormat driver would increase flexibility, but then it
becomes tricky to say which should inherit from which (in a single inheritence)
or what order methods should be resolved (in multiple inheritence).

Notes:
* Didn't finish refactoring SQL based drivers
* ServerDrivers refactoring not done.
* Since TDBCluster was the only cluster, didn't do MergableDriver

==== Inheritence Overview ====

  * BaseDBDriver - superclass of all drivers. Some shared utility methods
                   including support for persistent connections (ala TDB).
		   Thus this is a candidate for separating out the the
		   PersistentConnectionsDriver.
    * 70HyphenFormat - drivers that write and read their data via pipes to
                       external executables. Data is in simple Greenstone
		       archive form (i.e. key/value pairs and separated by
		       seventy hyphens) - this is a candidate for further
		       separating out a PipedExecutableDriver.
      * GDBM - makes use of GDBM utils (txt2db, db2txt etc)
      * GDBMTXTGZ - makes use of gzip (for later use with GDBM)
      * JDBM - makes use of jdbm.jar and JDBMWrapper.jar
      * TDB - makes use of TDB utils (txt2tdb, tdb2txt etc)
    * SQLDrivers - drivers that read/write their data using SQL commands
      * SQLITE - uses calls to SQLite3 via the command line
      * MSSQL
    * ServerDrivers - drivers that act as clients to externally running servers
      * GDBMS - makes use of a custom GDBM server
      * TDBS - makes use of a custom TDB server
    * MergableDrivers - ???
      * TDBC - ??? Knows how to merge several TDB files into one.
