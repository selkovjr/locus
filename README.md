# locus

A PostgreSQL extension for representing genomic loci as built-in data type with indexing and query support.

## Features

- Efficient representation of genomic loci in the form `contig:start-end` or `contig:position`.
- GiST indexing for overlap (`&&`) and containment operations
- A rich set of functions for manipulating genomic loci

## Usage

```sql
CREATE EXTENSION locus;

SELECT '16:89831249'::locus AS locus;
-- Returns 16:89831249

SELECT 'chr16:89831249-89831439'::locus AS locus;
-- Returns chr16:89831249-89831439

SELECT 'chr16:1,000,000-'::locus AS locus;
-- Returns chr16:1000000-  (1,000,000 .. ∞)

CREATE TABLE test_locus (l locus);
CREATE INDEX p_gist_ix ON test_locus USING gist(l)
SELECT * from test_locus where l <@ '12:112847287-112944263'
-- Returns all loci contained in the PTPN11 gene

SELECT * from t1 JOIN t2 ON t1.l && t2.l;
-- Perform a join on overlapping loci
```

## Testing Notes

PostgreSQL regression harness uses `psql` behind the scenes, which can add trailing whitespace to column names and values in the output, depending on the default formatting rule.

To normalize this, `diff -Z` is used via a custom wrapper script, `./diff`,
overriding the system `diff` command by patching `$(PATH)` in the `Makefile`. The local executable `./diff` is a symlink to `diff-ignore-trailing-space` (named so for clarity), which forks `/usr/bin/diff`. Replace that with the absolute path to your system `diff`, if different; the absolute path is needed to avoid an infinite loop.

You can run regression tests with:

```bash
make installcheck
```

## Known Issues

- Fixed internal storage (32 bytes) may be limiting. A version of the `locus` type can be easily built with `INTERNALLENGTH = VARIABLE`, at a cost in storage size and performance.


---
