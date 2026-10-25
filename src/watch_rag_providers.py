from __future__ import annotations

import json
import logging
import os
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any


class Embedder(ABC): 
    @abstractmethod
    def embed(self, text: str) -> list[float]: ...

    @abstractmethod
    def embed_all(self, text: list[str]) -> list[float]: ...



class ChatModel(ABC):
    @abstractmethod
    def complete(self, prompt: str) -> str: ...


@dataclass
class SearchHit:
    key: str
    score: float
    metadata: dict[str, Any]

@dataclass
class VectorPayload:
    id: int | str
    vector: list[float]
    payload: dict[str, Any]

class VectorStore(ABC):
    @abstractmethod
    def prepare_database(size: Any) -> None: ...

    @abstractmethod
    def search(self, vector: list[float], limit: int, filters: dict[str, Any]) -> list[SearchHit]: ...
    
    @abstractmethod
    def store(self, vector_struct: list[VectorPayload], batch_size: int) -> int: ...

    @abstractmethod
    def close() -> None: ...


class SentenceTransformerEmbedder(Embedder):
    def __init__(self, model: str):
        from sentence_transformers import SentenceTransformer
        self._model = SentenceTransformer(model)

    def embed(self, text: str) -> list[float]:
        return self._model.encode(text, show_progress_bar=True).tolist()

    def embed_all(self, text: list[str]) -> list[float]:
        return self._model.encode(text, show_progress_bar=True)


class BedrockEmbedder(Embedder):
    def __init__(self, model: str, region: str | None = None):
        import boto3
        self._client = boto3.client("bedrock-runtime", region_name=region)
        self._model = model

    def embed(self, text: str) -> list[float]:
        response = self._client.invoke_model(
            modelId=self._model,
            body=json.dumps({"inputText": text}),
        )
        return json.loads(response["body"].read())["embedding"]

    def embed_all(self, text: list[str]) -> list[float]:
        return [self.embed(item) for item in text]


class OllamaChat(ChatModel):
    def __init__(self, url: str, model: str):
        from ollama import Client
        self._client, self._model = Client(host=url), model

    def complete(self, prompt: str) -> str:
        response = self._client.chat(
            model=self._model,
            messages=[{"role": "user", "content": prompt}]
        )
        content = (response.message.content or "").strip()
        if not content:
            raise RuntimeError(f"Ollama model '{self._model}' returned an empty response.")
        return content


class BedrockChat(ChatModel):
    def __init__(self, model: str, region: str | None = None):
        import boto3
        self._client = boto3.client("bedrock-runtime", region_name=region)
        self._model = model

    def complete(self, prompt: str) -> str:
        response = self._client.converse(
            modelId=self._model,
            messages=[{"role": "user", "content": [{"text": prompt}]}],
        )
        return response["output"]["message"]["content"][0]["text"].strip()

class QdrantVectorStore(VectorStore):

    def __init__(self, url: str, collection: str):
        from qdrant_client import QdrantClient
        self._client = QdrantClient(url=url)
        self._collection = collection
        self._logger = logging.getLogger(__name__)

    def close(self):
        self._client.close()

    def prepare_database(self, size: Any) -> bool:
        from qdrant_client import models
        if self._client.collection_exists(collection_name=self._collection):
            self._client.delete_collection(collection_name=self._collection)
        self._client.create_collection(
            collection_name=self._collection,
            vectors_config=models.VectorParams(size=size, distance=models.Distance.COSINE),
        )
        return self._client.collection_exists(collection_name=self._collection)

    def store(self, vector_payload_data: list[VectorPayload], batch_size: int) -> int:
        from qdrant_client import models
        vectors = []
        for vector_payload_row in vector_payload_data:
            vectors.append(
                models.PointStruct(
                    id=vector_payload_row.id,
                    vector=vector_payload_row.vector,
                    payload=vector_payload_row.payload
                )
            )

        total_points = len(vectors)

        for i in range(0, total_points, batch_size):
            batch = vectors[i:i + batch_size]
            self._logger.debug(f"Upserting batch {i // batch_size + 1} of {((total_points - 1) // batch_size) + 1} (size: {len(batch)})...")
            self._client.upsert(
                collection_name=self._collection,
                points=batch
            )
        return total_points

    def search(self, vector: list[float], limit: int, filters: dict[str, Any]) -> list[SearchHit]:
        from qdrant_client import models
        query_must_conditions = []
        for key, value in filters.items():
            query_must_conditions.append(
                models.FieldCondition(
                    key=key,
                    match=models.MatchValue(value=value)
                )
            )

        response = self._client.query_points(
            collection_name=self._collection,
            query=vector,
            query_filter=models.Filter(must=query_must_conditions),
            with_payload=True,
            with_vectors=True,
            limit=limit
        )
        return [SearchHit(v.id, v.vector, v.payload)
                for v in response.points]

class S3VectorsStore(VectorStore):
    logger = logging.getLogger(__name__)

    def __init__(self, bucket: str, index: str, region: str | None = None):
        import boto3
        self._client = boto3.client("s3vectors", region_name=region)
        self._bucket, self._index = bucket, index
        self._logger = logging.getLogger(__name__)

    def close(self):
        pass

    def prepare_database(self, size: Any) -> bool:
        pass

    def store(self, vector_payload_data: list[VectorPayload], batch_size: int) -> int:
        total_vectors = len(vector_payload_data)
        batch_size = min(batch_size, 500)

        for i in range(0, total_vectors, batch_size):
            batch = vector_payload_data[i:i + batch_size]
            self._logger.debug(
                f"Putting batch {i // batch_size + 1} of "
                f"{((total_vectors - 1) // batch_size) + 1} (size: {len(batch)})..."
            )
            self._client.put_vectors(
                vectorBucketName=self._bucket,
                indexName=self._index,
                vectors=[
                    {
                        "key": str(point.id),
                        "data": {"float32": [float(value) for value in point.vector]},
                        "metadata": point.payload,
                    }
                    for point in batch
                ],
            )
        return total_vectors

    def search(self, vector: list[float], limit: int, filters: dict[str, Any]) -> list[SearchHit]:
        response = self._client.query_vectors(
            vectorBucketName=self._bucket,
            indexName=self._index,
            queryVector={"float32": vector},
            filter=filters or None,
            returnDistance=True,
            returnMetadata=True,
            topK=limit
        )
        return [SearchHit(v["key"], v.get("distance", 0.0), v.get("metadata", {}))
                for v in response.get("vectors", [])]


def create_embedder(provider: str, model: str) -> Embedder:
    if provider == "bedrock":
        return BedrockEmbedder(model, os.getenv("AWS_REGION"))
    return SentenceTransformerEmbedder(model)


def create_chat(provider: str, model: str, ollama_url: str | None) -> ChatModel:
    if provider == "bedrock":
        return BedrockChat(model, os.getenv("AWS_REGION"))
    return OllamaChat(ollama_url.strip(), model)

def create_vector_store(bucket: str | None = None, url: str | None = None, collection: str | None = None) -> VectorStore:
    if bucket != None and collection != None:
        return S3VectorsStore(bucket=bucket, index=collection, region=os.getenv("AWS_REGION"))
    elif url != None and collection != None:
        return QdrantVectorStore(url, collection)
    else:
        raise RuntimeError(f"Failed to create VectorStore.")