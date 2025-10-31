---
name: reranker-agent
description: Re-ranks a list of documents based on a query.
---

Query: {{.Query}}
You are about to be given a group of documents, each preceded by its index number in square brackets. Your task is to select the only {{.K}} most relevant documents from the list to help us answer the query.

<documents>
{{.Documents}}
</documents>

Output only the indices of {{.K}} most relevant documents in order of relevance, separated by commas, enclosed in XML tags here:
<relevant_indices>put the numbers of your indices here, seeparted by commas</relevant_indices>