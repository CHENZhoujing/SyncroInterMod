/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Jul 7, 2024 at 5:02:19 AM
 *********************************************/

using CP;

tuple ArcInfo {
    string start;
    string end;
}

tuple GoodsInfo {
    string good;
    string origin;
    string destination;
    float capacity;
    float departuretime;
    float arrivaltime;
    float penalty;              
}

{ArcInfo} Arcs = ...; // 定义弧的信息集合 // Define the set of arc information
setof(string) Nodes = ...; // 所有节点，包括起点、终点和转运节点 // All nodes, including origin, destination, and transfer nodes
setof(string) Modes = ...; // 所有运输方式 // All modes of transportation
{GoodsInfo} GoodsDetails = ...; // 每个物品的详细信息，包括起点、终点，重量，出发时间限制，到达时间限制，超时惩罚
setof(string) Goods = {gd.good | gd in GoodsDetails}; // 从GoodsDetails中提取物品集合 // Extract the set of goods from GoodsDetails

float Transitcost[Arcs][Modes] = ...; //运输网络运输成本矩阵
float Departuretime[Arcs][Modes] = ...; //运输网络开始时间矩阵
float Arrivaltime[Arcs][Modes] = ...; //运输网络到达时间矩阵
float Capacity[Arcs][Modes] = ...; //运输网络运输能力矩阵
float Carbonemissions[Arcs][Modes] = ...; //运输网络碳税矩阵，可以和运输成本矩阵合并

dvar boolean x[Goods][Arcs][Modes]; // 选择某条弧上的某种运输方式，用于特定的物品 // Select a specific transportation mode on a specific arc for a particular good
dvar boolean timeViolation[Goods]; // 时间违规变量 // Time violation variable

// 目标函数 运输成本和超时成本 // Objective function: Transportation cost and overtime cost
minimize 
    sum(gd in GoodsDetails, a in Arcs, m in Modes) Transitcost[a][m] * x[gd.good][a][m] // 运输成本 
    + sum(gd in GoodsDetails, a in Arcs, m in Modes) Carbonemissions[a][m] * x[gd.good][a][m]
    + sum(gd in GoodsDetails) gd.penalty * timeViolation[gd.good]; // 超时成本 // Overtime cost

// 约束条件 // Constraints
subject to {
    // 每个物品从其起点出发 // Each good must depart from its origin
    forall(gd in GoodsDetails)
        sum(a in Arcs, m in Modes : a.start == gd.origin) x[gd.good][a][m] == 1;

    // 每个物品到达其终点 // Each good must arrive at its destination
    forall(gd in GoodsDetails)
        sum(a in Arcs, m in Modes : a.end == gd.destination) x[gd.good][a][m] == 1;

    // 每个物品在转运节点的流量平衡 // Flow balance for each good at transfer nodes
    forall(gd in GoodsDetails, n in Nodes : !(n == gd.origin) && !(n == gd.destination))
        sum(a in Arcs, m in Modes : a.end == n) x[gd.good][a][m] == sum(a in Arcs, m in Modes : a.start == n) x[gd.good][a][m];
       
 	// 出发时间约束
	forall(gd in GoodsDetails, a in Arcs, m in Modes : a.start == gd.origin)
    	gd.departuretime <= Departuretime[a][m];

	// 到达时间约束
	forall(gd in GoodsDetails, a in Arcs, m in Modes : a.end == gd.destination)
    	Arrivaltime[a][m] <= gd.arrivaltime + timeViolation[gd.good] * 1e6;
    	
   	//节点时间限制
   	forall(a1 in Arcs, a2 in Arcs: a1.end == a2.start)
   	  	
   	  	

    // 每条弧上的总运输量不能超过其容量限制 // Total transported weight on each arc must not exceed its capacity
    forall(a in Arcs, m in Modes)
        sum(gd in GoodsDetails) gd.capacity * x[gd.good][a][m] <= Capacity[a][m];
        
}

// 输出结果 // Output results
execute {
    writeln("Optimal transportation plan:");
    for(var gd in GoodsDetails) {
        for(var a in Arcs) {
            for(var m in Modes) {
                if(x[gd.good][a][m] > 0.5) {
                    writeln("Transport good ", gd.good, " on arc from ", a.start, " to ", a.end, " using mode ", m);
                }
            }
        }
    }
   	for(var gd in GoodsDetails) {
        if (timeViolation[gd.good] == 1) {
            writeln("Time violation for good: ", gd.good);
        }
  	}    
}