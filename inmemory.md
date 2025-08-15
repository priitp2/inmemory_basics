---
marp: true
theme: default
size: 4K
auto-scaling: true
paginate: true
---

# Oracle In-Memory: basics and beyond
### Priit Piipuu
### 14.11.2025

---
# What it's all about

* A gentle introduction to the in-memory analytics
* Oracle In-Memory basics
* What is under the hood?
* Other cool stuff

<!-- 
One reason for this presentation is now there's some buzz around in-memory analytics and
Apache Arrow in the free software world. At last, Oracle In-Memory might get competitiors.
-->
---

# Presentation and scripts available in Github
![](img/pres_qrcode.png)


---

# What makes computation fast?

<!-- Find out what the CPU is doing and do it less.
CPU mostly waits for the caches to be filled
Cache-aware algorithms and programming styles give better performance. -->

---

![bg w:auto h:auto](ex/mem_hierarchy.png)

<!--
Adapted from Bryant & Hallaron, "Computer Systems: A Programmer's Perspective"
-->
---

![](img/ram_is_the_new_disk.png)

<!-- Tanel Põder, “RAM is the new disk” series: https://tanelpoder.com/2015/08/09/ram-is-the-new-disk-and-how-to-measure-its-performance-part-1/
-->

---
# Data-oriented design

Operates on arrays, this avoids call overhead and cache misses
Prefers arrays to structures, gives better cache usage
Inlines subroutines, avoids deep call hierarchies
Tight control on memory allocation

<!-- We’re mostly talking about the first point: arrays and other continuous memory regions. This gives better data locality and CPU cache hit ratio.

In context of data analytics, it is not a free lunch. More often than not, data has to be turned into CPU-friendly format and that takes an effort.
-->

---

# Apache Arrow (I)

Framework and data interchange format
Language agnostic in-memory data structure specification
Metadata serialisation
Protocol for serialisation and generic data transport

<!-- Binary data format suitable for both in-memory processing and export. Avoids the overhead of serialization and deserialization: same format for in-memory processing, IPC/networking, and long-term storage. Shredding for the nested data: each location of structs or json documents gets its separate column.
-->

---
# Apache Arrow (II)

Implementations for specific languages

Dremio: query engine and data warehouse built around Arrow.

---
# Arrow columnar format

Data adjacency for sequential access
Constant time random access
Plays well with SIMD and vectorization
Zero-copy access
No compression

---
# Implementations

C/C++
Pyarrow (wrapper around the C/C++ library)
Pola.rs (written in Rust, adds SQL support and other cool features)

---

# Oracle In-Memory
---
# Oracle In-Memorya (I)
In-Memory column store (Ppart of the SGA)
Query optimizations
Availability and automation
Integration with the Oracle features

---

# Oracle In-Memory (II)

On CDB/instance level:
   ```sql
   alter system set inmemory_size = 16G scope = spfile
   ``` 
On PDB level:
   ```sql
   alter system set inmemory_size = 8G scope = spfile;
   ```
<!-- 
PDBs can share the inmemory area configured on the CDB/instance level
It is possible to distribute inmemory area between the PDBs
-->
---

# Automatic In-Memory sizing in 23ai

Can automatically shrink or grow In-Memory area.
`inmemory_size` becomes minimum size for In-Memory
`INMEMORY_LEVEL` should be set to `MEDIUM` or `HIGH` 
ASMM manages In-Memory Area with other SGA components

<!-- 
In-Memory Area sizing can be either manual or automatic (in 23ai)
-->
---

# Oracle In-memory Base Level

Oracle EE feature
IM column store size less than 16GB per CDB or instance
Compression level is set to `QUERY LOW`
No Automatic In-Memory
```sql
alter system set inmemory_force = base_level scope = spfile;
```

---
# Oracle In-memory and competitors
||Arrow implementations|Oracle In-Memory|
|---|---|---|
|Data types |Has own type system|Subset of SQL types|
|Access|Constant time random access|Through SQL queries|
|Transactional|No|Yes|
|Compute functions| Yes | In-Memory expressions|
|Automatic parallelization|Yes|Yes|
|Automatic memory management|Not really/depends|Yes|
|Automatic In-Memory|No|Yes|
---

# Populating the column store

During the population
*   Database reads row format data from the disk
*   Transforms into columnar format
*   Stores it in the IM column store

---

# Repopulation

Transforms *new* data into columnar format
Creates new IMCUs

<!--
IMCUs are read only, so new data is added to the transaction journal and new IMCUs are created during the repopulation.
-->
---

# `INMEMORY` attribute can be specified for

Tablespaces
Tables
Matrialized views
Set of columns

```sql
```
---

# `INMEMORY` attribute

Objects that can't be populated:
* Indexes
* Index-oriented tables
* Hash clusters
* Objects owned by SYS
* Objects in `SYSTEM` or `SYSAUX` tablespaces 

---

# Ineligible data types

Data types that can't be populated:
* Out-of-line columns like varrays, nested table columns 
* `LONG` or `LONG RAW` data types
* Extended data types

---

# Partitioned tables

In-Memory can be specified either on table level or partition level
Partitions inherit table-level clause
Works with hybrid partitioning, but rsults may vary

---

# External tables and external partitions

Some limitations:
* No subpartitions
* Column, distribute and priority clauses are not valid
* No join groups, In-Memory Optimized Arithmetic, In-Memory Expressions

---

# In-Memory and LOBs

Out-of-line LOBs can't be populated, IM column store saves only the locator


Inline LOBS:
* IM column store allocates 4KB of continuous buffer space
* For OSON data upper limit is 32KB

---

![](img/syntax0.png)

---

![](img/syntax_memcompress.png)

<!--

NO MEMCOMPRESS -> no compression.
MEMCOMPRESS AUTO -> database manages automatically eviction, recompression and population. New in 23ai.
MEMCOMPRESS FOR DML -> little or no compression, optimized for DML
QUERY LOW -> default level, should give best query performance
CAPACITY LOW -> according to documentation gives excellent query performance as well

-->

---

![](img/syntax_priority.png)

<!--
PRIORITY clause controls priority of the population and not speed.
NONE -> On-demand population, data will be populated only if table is accessed through full table scan. This is default.

With priority LOW .. CRITICAL data is populated through internally managed priority queue. Higer priority segments will get precedence over the lower precedence segments. In case of the lack of space, data is not populated until space is available.
-->

---

# Under the Hood

---

![bg w:auto h:auto](img/imcu3.png)

<!--
In-Memory compression unit (IMCU) contains Compression Units with the column data (from
one or more columns), and the header. IMCU header contains various metadata, and might
contain IM storage index. IMCU stores data from one and only object. IMCU includes all
the columns from the table.

Columns in IMCU are not sorted, IMCUs are populated in the order data is read from the
disk. IMCU allocates space in contiguous 1M pieces (extents)

Column Compression Units (CU) is continuous storage for a single column. CU has a body
and a header. Header contains metadata about the values stored in CU (min and max values
stored). It may contain local dictionary (for dictionary encoding?) The CU stores values
in ROWID order.

IMCU contains ROWIDs as well, this is how column values are stitched together. (In case
of join group, local dictionaries contain references to the common dictionary) 

Snapsot Metadata Unit contains metadata for associated IMCU (1:1). Contains object
numbers, column numbers, mapping info for columns and transaction journal. When row
in the buffer cache changes, then database adds modified row(id?) to the SMU and marks
it stale as of SCN. Recent versions will come from buffer cache.

-->
---

![bg w:auto h:auto](img/imcu_single.png)

<!--
In-Memory compression unit (IMCU) contains Compression Units with the column data
(from one or more columns), and the header. IMCU header contains various metadata,
and might contain IM storage index. IMCU stores data from one and only object. IMCU
includes all the columns from the table.

Columns in IMCU are not sorted, IMCUs are populated in the order data is read from the
disk. IMCU allocates space in contiguous 1M pieces (extents)

Column Compression Units (CU) is continuous storage for a single column. CU has a body
and a header. Header contains metadata about the values stored in CU (min and max values
stored). It may contain local dictionary (for dictionary encoding?) The CU stores values
in ROWID order. IMCU contains ROWIDs as well, this is how column values are stitched
together. (In case of join group, local dictionaries contain references to the common
dictionary) 

-->
---

# Snapshot metadata units
Every IMCU has a separate SMU
SMU contains metadata for IMCU (Object and column numbers, mapping for rows)
SMU contains transaction journal

---

# Transaction journal
Keeps IMCU transactionally consistent
In case of a change database adds rowid to the journal and marks it stale as of SCN
Stale rows are read from buffer cache

---

# In-Memory expression units
Stores materialized In-Memory expressions and virtual columns
Logical extension of the parent IMCU
Maps to the same rowset as IMCU

---

# Expression statistics store
* Maintained by the optimizer, stores statistics about expression evaluation
* Part of the data dictionary, used for IM expressions
* Exposed as DBA_EXPRESSION_STATISTICS view

---

![w:auto h:auto](img/pools.png)

<!-- 
Screenshot is from 21.13
Columnar data pool (IMCUs), 1MB pool in V$INMEMORY_AREA
Metadata pool, 64KB pool in V$INMEMORY_AREA
“IM pool metadata”, IM POOL METADATA in V$INMEMORY_AREA
“Metadata pool” stores metadata about the objects that reside in the Im column store. “IM pool metadata” stores other metadata which can’t be stored in metadata pool.

-->
---

# In-Memory store population and repopulation
Happens magically
Tasks are coordinated by In-Memory Coordination Process (IMCO)
Actual work is done by Space Management Worker Processes (Wnnn)

---

# In-Memory store population
IMCO triggers population of all segments with priority higher than NONE
Segments with priority NONE are populated after they’re scanned
Workers create IMCUs, SMUs, and IMEUs

<!-- 
IMCO wakes up
Checks if repopulation od IMCUs is needed
Triggers Wnnn to do the work
SMCO sleeps for 2 minutes

-->

---
# In-Memory store repopulation (I)
Thresold-based, triggered when # of stale entries in IMCU reaches the threshold
Thresold is percentage of entries in transaction journal
Double buffering: new IMCU is created by combining old IMCUs with transaction journals

<!-- 
During repopulation, old IMCUs remain accessible. IMEUs can be added later, without repopulating the IMCU
-->
---
# In-Memory store repopulation (II)
`INMEMORY_MAX_POPULATE_SERVERS` -> max number of workers
`INMEMORY_TRICKLE_REPOPULATE_PERCENT` -> max percent of time workers can do trickle repopulation

---
# In-Memory dynamic scans (I)
Uses threads to scan the IMCUs
Uses idle CPU

![w:auto h:auto](img/parallel.png)

---
# In-Memory dynamic scans (II)

Enabled when a CPU resource plan is enabled and CPU utilization is low
`CPU_COUNT` must be `>= 24`

Query is candidate for dynamic scan if 
   * It access high number of IMCUs or columns
   * Consumes all rows in the table
   * Is CPU intensive

---

![w:820 h:640](img/dynamic_scans.png)

<!-- 
Screenshot is from 19c RAC.
-->
---

# In-Memory joins
IMCUs encoded with different dictionaries have to be decoded to be joinable
In-Memory join groups encode different tables with the same dictionary

<!-- 
TABLE ACCESS IN MEMORY FULL operation in the query plan means that between zero and all the data is read from the IM column store.
-->

---

# Compression
Levels from FOR DML to FOR CAPACITY HIGH
FOR QUERY handles NUMBERs

<!-- 
Oracle NUMBER data type is a composite data type and thus not especially CPU friendly. FOR QUERY and better compression levels transform it to something more computable.

FOR QUERY LOW seems to be using dictionary encoding only, FOR CAPACITY HIGH uses Zstandard.

-->
---

# It happens all in runtime

Does TABLE ACCESS IN MEMORY FULL access path mean data comes from the In-Memory?

<!-- 
Data might be stale. Segments might not be loaded into In-memory, for example in RAC. Or your query might mix and match columns that are not loaded into In-memory: in that case data will come from the buffer cache. And query optimizer is totally oblivious about what decision are taken during the scan.
-->
---

![](img/inm_stats.png)

---

# Thank you!