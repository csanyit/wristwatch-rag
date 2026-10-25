# watch-rag

Semantic search over watch specifications. Watch rows from a CSV are turned into text embeddings, stored in [Qdrant](https://qdrant.tech/), and queried with a human-readable sentence. Optional brand and family filters can narrow the results.

The project has two packages:

- `vector_db_builder` — load a semicolon-delimited CSV, embed each watch, and (re)create the Qdrant collection
- `rag_query` — encode a free-text query with the same model and search the collection

## Set up

Python 3.10 or newer is required. Qdrant must be reachable at the URL in the properties file (default: `http://localhost:6333`).

Create and activate a virtual environment, then install the project:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -e .
```

Start Qdrant if it is not already running, for example:

```bash
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

Both packages read settings from a common properties file. That file sets the Qdrant URL, collection name, insert batch size, query limit, and sentence-transformer model.

## Deploy Lambda code

The `Deploy wristwatch RAG code` GitHub Actions workflow packages the selected function from `src/` together with `src/watch_rag.properties`, then uploads it to `s3://<LAMBDA_CODE_BUCKET>/<lambda_name>/<lambda_name>.zip`. Configure the `AWS_ROLE_ARN` and `LAMBDA_CODE_BUCKET` secrets in the selected GitHub Actions environment. The deployment role must allow uploading objects to that bucket.

The CSV must use `;` as the delimiter. Rows with an empty `Brand` are skipped. Columns used when building the text that is embedded include brand, family, name, reference, movement, case, dial, glass, and description.

## Start

Build (or rebuild) the vector database from a CSV. This deletes the collection if it already exists, then inserts the new vectors:

```bash
python -m vector_db_builder path/to/watches.csv
```

Search with a free-text sentence. Brand and family are optional payload filters:

```bash
python -m rag_query --query_text "steel dive watch with a black dial"

python -m rag_query --query_text "automatic chronograph" --brand "Omega" --family "Speedmaster"
```