---
marp: true
theme: default
size: 4:3
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

# What makes computation fast?

<!-- Find out what the CPU is doing and do it less.
CPU mostly waits for the caches to be filled
Cache-aware algorithms and programming styles give better performance. -->

---

![](ex/mem_hierarchy.png)

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

# Oracle In-memory and competitors

||Arrow implementations|Oracle In-Memory|
|---|---|---|
|Data types |Has own type system|Subset of Oracle SQL types|
|Access|Constant time random access|Through SQL queries|
|Compute functions| Yes | Through In-Memory expressions|
|Automatic parallelization|Yes|Yes|
|Automatic memory management|Not really/depends|Yes|


---
