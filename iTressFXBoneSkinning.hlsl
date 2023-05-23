#ifndef THREAD_GROUP_SIZE
#define THREAD_GROUP_SIZE 64
#endif
#define AMD_TRESSFX_MAX_NUM_BONES 256

cbuffer ConstBufferCS_BoneMatrix
{
	row_major float4x4 g_BoneSkinningMatrix[AMD_TRESSFX_MAX_NUM_BONES];
	int g_NumMeshVertices;
}

struct BoneSkinningData
{
	float4 boneIndex; // x, y, z and w component are four bone indices per strand
	float4 boneWeight; // x, y, z and w component are four bone weights per strand
};

// SRVs
StructuredBuffer<BoneSkinningData> g_BoneSkinningData;
StructuredBuffer<StandardVertex> initialVertexPositions;

[numthreads(THREAD_GROUP_SIZE, 1, 1)]
void BoneSkinning(uint GIndex : SV_GroupIndex, uint3 GId : SV_GroupID, uint3 DTid : SV_DispatchThreadID)
{
	uint local_id = GIndex;
	uint group_id = GId.x;
	uint global_id = local_id + group_id * THREAD_GROUP_SIZE;

	if (global_id >= g_NumMeshVertices)
		return;

	float3 pos = initialVertexPositions[global_id].position;
	float3 n = initialVertexPositions[global_id].normal;

	// compute a bone skinning transform
	BoneSkinningData skinning = g_BoneSkinningData[global_id];

	// Interpolate world space bone matrices using weights. 
	row_major float4x4 bone_matrix = g_BoneSkinningMatrix[skinning.boneIndex[0]] * skinning.boneWeight[0];
	float weight_sum = skinning.boneWeight[0];

	// Each vertex gets influence from four bones. In case there are less than four bones, boneIndex and boneWeight would be zero. 
	// This number four was set in Maya exporter and also used in loader. So it should not be changed unless you have a very strong reason and are willing to go through all spots. 
	for (int i = 1; i < 4; i++)
	{
		if (skinning.boneWeight[i] > 0)
		{
			bone_matrix += g_BoneSkinningMatrix[skinning.boneIndex[i]] * skinning.boneWeight[i];
			weight_sum += skinning.boneWeight[i];
		}
	}

	bone_matrix /= weight_sum;

	pos.xyz = mul(float4(pos.xyz, 1), bone_matrix).xyz;
	n.xyz = mul(float4(n.xyz, 0), bone_matrix).xyz;
	collMeshVertexPositions[global_id].position = pos;
	collMeshVertexPositions[global_id].normal = n;
}