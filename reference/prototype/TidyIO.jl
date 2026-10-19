# Arrow IPC and Parquet sources for Tidy's lazy scan.
# Kept out of Tidy.jl so the core stays stdlib-only; this module only
# implements the Source interface (schema, partitions, read_partition, stats).
module TidyIO

using Arrow, Parquet2, Tables
import ..Tidy
using ..Tidy: Tbl, Source

export scan_arrow, scan_parquet

schema_pairs(sch) = [n => T for (n, T) in zip(sch.names, sch.types)]

# ── Arrow: memory-mapped, zero-copy. Partitions are (record batch, row range),
#    so a large batch is still split into morsels. Arrow has no min/max stats.
struct ArrowSource <: Source
    path::String
    table::Arrow.Table
    nrows::Int
    nbatches::Int
end

batches(col) = hasproperty(col, :arrays) ? col.arrays : [col]   # SentinelArrays.ChainedVector chunks

function scan_arrow(path)
    at = Arrow.Table(path)
    first_col = Tables.getcolumn(at, first(Tables.columnnames(at)))
    Tidy.lazy(ArrowSource(path, at, length(first_col), length(batches(first_col))))
end

Tidy.schema(s::ArrowSource) = schema_pairs(Tables.schema(s.table))
Tidy.describe(s::ArrowSource) = "arrow $(basename(s.path)) ($(s.nrows) rows, $(s.nbatches) record batches)"
function Tidy.partitions(s::ArrowSource, morsel)
    lens = length.(batches(Tables.getcolumn(s.table, first(Tables.columnnames(s.table)))))
    [(b, r) for (b, n) in enumerate(lens) for r in Iterators.partition(1:n, morsel)]
end
function Tidy.read_partition(s::ArrowSource, (b, r), cols)
    col(n) = view(batches(Tables.getcolumn(s.table, n))[b], r)          # no copy for primitives
    Tbl(NamedTuple{Tuple(cols)}(map(col, Tuple(cols))))
end

# ── Parquet: partitions are row groups; only the requested column chunks are
#    decoded, and row groups whose min/max cannot match a pushed filter are skipped.
struct ParquetSource <: Source
    path::String
    ds::Parquet2.Dataset
end

scan_parquet(path) = Tidy.lazy(ParquetSource(path, Parquet2.Dataset(path)))

plain(v::AbstractVector{<:AbstractString}) = Vector{String}(v)    # WeakRefStrings point into the file buffer
plain(v) = v

Tidy.schema(s::ParquetSource) = schema_pairs(Tables.schema(s.ds))
Tidy.describe(s::ParquetSource) =
    "parquet $(basename(s.path)) ($(sum(Parquet2.nrow, s.ds)) rows, $(length(s.ds)) row groups)"
Tidy.partitions(s::ParquetSource, morsel) = collect(1:length(s.ds))
function Tidy.read_partition(s::ParquetSource, k, cols)
    rg = s.ds[k]
    Tbl(NamedTuple{Tuple(cols)}(map(n -> plain(Parquet2.load(rg, string(n))), Tuple(cols))))
end
function Tidy.stats(s::ParquetSource, k, col)
    st = try
        Parquet2.ColumnStatistics(s.ds[k][string(col)])
    catch
        return nothing
    end
    lo, hi = minimum(st), maximum(st)
    lo === nothing || hi === nothing ? nothing :
        any(x -> x isa AbstractFloat && isnan(x), (lo, hi)) ? nothing : (lo, hi)    # a NaN in the group poisons min/max
end

end # module
