# watch-rag

Semantic search over watch specifications. Watch rows from a CSV are turned into text embeddings, stored in [Qdrant](https://qdrant.tech/), and queried with a human-readable sentence. Optional brand and family filters can narrow the results.

The project has two packages:

- `vector_db_builder` — load a semicolon-delimited CSV, embed each watch, and (re)create the Qdrant collection
- `rag_query` — encode a free-text query with the same model and search the collection

## Set up

Python 3.10 or newer is required. Qdrant must be reachable at the URL in the properties file (default: `http://localhost:6333`).

Using `uv`, install the dependencies for the local self-hosted setup:

```bash
uv sync --extra lambda-builder-self-hosted
```

This installs the Ollama, Qdrant, and Sentence Transformers dependencies needed by the local `__main__.py` commands. For a Bedrock-based environment, use instead:

```bash
uv sync --extra lambda-builder-bedrock
```

Start Qdrant if it is not already running, for example:

```bash
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

Both packages read settings from a common properties file. That file sets the Qdrant URL, collection name, insert batch size, query limit, and sentence-transformer model.

The collection name defaults to `VectorDB.collection.name` in `src/watch_rag.properties`. Set `VECTORDB_DB_NAME` to override it for both the builder and query commands; an unset or blank value falls back to the properties file. The embedding model defaults to `Model.sentence_transformer_model.name`; set `VECTORDB_MODEL_NAME` to override it for both commands (use the same model when building and querying). The Ollama model name defaults to `LLM.ollama.model.name`; set `LLM_MODEL_NAME` to override it for query commands. For Lambda deployments, configure the relevant environment variables on the Lambda function to override these settings.

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
