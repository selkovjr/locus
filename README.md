# locus

A PostgreSQL extension for representing genomic loci as composite types with indexing and query support.

## Features

- Efficient representation of genomic loci in the form `contig:start-end` or `contig:position`.
- GiST indexing for overlap (`&&`) and containment operations
- Optional tiling via `locus_tile_id()` to group loci into genomic tiles for efficient JOINs and aggregations.

## Usage

```sql
CREATE EXTENSION locus;

SELECT locus_tile_id('chr1:100000-100999');
-- Returns: 'chr1:100'

SELECT locus_tile_id('chr1:100000-100999', 1000000);
-- Returns: 'chr1:100'
```

## Tiling

The `locus_tile_id(locus, tile_size)` function computes a tile ID string like `contig:tile_start`, where:

- `contig` is the locus contig (e.g., 'chr1')
- `tile_start` is the lower coordinate rounded down to the nearest tile boundary
- `tile_size` (optional) defaults to 1,000,000

Example:
```sql
SELECT locus_tile_id('2:112847287-112847500');
-- '2:112000000'
```

## Testing Notes

PostgreSQL 12's regression harness preserves trailing whitespace in output.
To normalize this, `diff -Z` is used via a custom wrapper script, `./diff`,
overriding the system `diff` command by patching $PATH in `Makefile`.

You can run regression tests with:

```bash
make installcheck
```

If trailing spaces still cause issues, check `./diff-ignore-trailing-space` or use:

```bash
diff -Z expected/locus.out results/locus.out
```

## Known Issues

- Fixed internal storage (32 bytes) may be limiting for assemblies with long contig names.
- Performance of `locus_tile_id()` in large joins needs further evaluation.


---

### 📈 2. Performance Testing of `locus_tile_id()`

We previously noticed that using `locus_tile_id()` slowed down a join. Now that it's working and passes regression tests, let's design a fair benchmark:

#### 🧪 Test Setup:

1. **Dataset Size**: Use a real-world scale — e.g., 10M rows.
2. **Test Queries**:
   - Join without tiling:
     ```sql
      SELECT * FROM t t1 JOIN t t2 ON t1.pos && t2.pos
     ```
   - Join with tiling:
     ```sql
     SELECT * FROM (
       SELECT *, locus_tile_id(pos) AS tile FROM t
     ) t1_ext
     JOIN (
       SELECT *, locus_tile_id(pos) AS tile FROM t
     ) t2_ext
     ON t1_ext.tile = t2_ext.tile AND t1_ext.pos && t2_ext.pos;
     ```
3. **Measure**:
   - Total runtime (`EXPLAIN ANALYZE`)
   - Rows processed
   - Index usage
   - Join strategy (`Nested Loop`, `Hash Join`, etc.)

#### 🧩 Potential Improvements:

If `locus_tile_id()` proves to be the bottleneck:
- Consider caching the tile column.
- Index it (e.g., `CREATE INDEX ON t (tile)`).
- Explore using `STORED` generated columns in PG ≥12:
  ```sql
  ALTER TABLE t ADD COLUMN tile text GENERATED ALWAYS AS (locus_tile_id(pos)) STORED;

