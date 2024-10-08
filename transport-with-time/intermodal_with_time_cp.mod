/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Jul 21, 2024 at 4:01:47 PM
 *********************************************/

using CPLEX;

// Transportation service information set
// 运输服务的信息集合
tuple ServiceInfo {
    string modality;         // Transportation mode (运输方式)
    string origin;           // Origin (起点)
    string destination;      // Destination (终点)
    int capacity;            // Transportation capacity (运输容量)
    float departuretime;     // Departure time (出发时间)
    float arrivaltime;       // Arrival time (到达时间)
    float transittime;       // Transit time (运输时间)
    float transitcost;       // Transportation cost (运输成本)
    float carbonemissions;   // Carbon emissions (碳排放量)
}

// Collection of detailed information for each good
// 每个物品的详细信息集合
tuple GoodInfo {
    string good;             // Good name or identifier (物品名称或标识)
    string origin;           // Origin (起点)
    string destination;      // Destination (终点)
    int capacity;            // Capacity (容量)
    float departuretime;     // Departure time (出发时间)
    float arrivaltime;       // Arrival time (到达时间)
    float penalty;           // Overtime penalty (超时惩罚)
}

{ServiceInfo} Services = ...; // Set of transportation service information (运输服务信息集合)
setof(string) Nodes = ...;     // All nodes, including origin, destination, and transfer nodes (所有节点，包括起点、终点和转运节点)
setof(string) Modes = ...;     // All transportation modes (所有运输方式)

{GoodInfo} GoodsDetails = ...; // Collection of detailed information for each good (每个物品的详细信息集合)
setof(string) Goods = {gd.good | gd in GoodsDetails}; // Set of goods (物品集合)

dvar int+ x[Goods][Services]; // Transportation quantity of each good on each service (每个物品在某个服务上的运输量)
dvar int+ positiveDelay[Goods]; // Time violation variable (时间违规变量)
dvar boolean useService[Goods][Services]; // Auxiliary binary variable indicating whether the good uses a service (辅助二进制变量，表示货物是否使用了某个服务)

dvar float+ goodArrivalTime[Goods][Nodes]; // Arrival time of each good at each node (每个货物在每个节点的到达时间)
dvar float+ goodDepartureTime[Goods][Nodes]; // Departure time of each good at each node (每个货物在每个节点的离开时间)

// float BigM = 1e6;
float timelimit = ...;
float epgap = ...;
float disasterimpact = ...;

// Loading and unloading costs and times (indexed by transportation modes)
// 装卸费用和时间（以运输方式为索引）
float LoadingCost[Modes] = [18.0, 18.0, 3.0];
float UnloadingCost[Modes] = [18.0, 18.0, 3.0];
float LoadingTime[Modes] = [1.0, 1.0, 0.0];
float UnloadingTime[Modes] = [1.0, 1.0, 0.0];

float StorageCostPerHour = 1.0; // Storage cost per hour (仓储费用)
float CarbonTaxPerTon = 8.0; // Carbon tax per ton (碳税)

execute PRE_PROCESSING {
  cplex.tilim = timelimit;
  cplex.epgap = epgap;
}

// Objective function
// 目标函数
minimize 
    // Transportation cost and carbon emission cost
    // 运输成本和碳排放成本
    sum(gd in GoodsDetails, s in Services) (
        s.transitcost * x[gd.good][s] + s.carbonemissions * x[gd.good][s] * CarbonTaxPerTon / 1000
    )
    // Loading and unloading costs
    // 装卸成本
    + sum(gd in GoodsDetails, s in Services) (
        (LoadingCost[s.modality] + UnloadingCost[s.modality]) * x[gd.good][s]
    )
    // Storage cost
    // 仓储成本
    + sum(gd in GoodsDetails) (
    	StorageCostPerHour * gd.capacity * (
       		max(n in Nodes) (goodArrivalTime[gd.good][n]) 
       		- sum(s in Services) (useService[gd.good][s] * (s.transittime + LoadingTime[s.modality] + UnloadingTime[s.modality]))
       		- gd.departuretime
        )
    )
    
    // Overtime penalty cost
    // 超时惩罚成本
    //+ sum(gd in GoodsDetails) gd.penalty * timeViolation[gd.good] * gd.capacity * (goodArrivalTime[gd.good][gd.destination] - gd.arrivaltime);
  	+ sum(gd in GoodsDetails) gd.penalty * gd.capacity * positiveDelay[gd.good];

// Constraints
// 约束条件
subject to {
    // Flow balance constraints for goods
    // 物品的流量平衡约束
    forall(gd in GoodsDetails) {
        // Origin node
        // 起点
       	sum(s in Services: s.origin == gd.origin) useService[gd.good][s] == 1;
        sum(s in Services: s.origin == gd.origin) x[gd.good][s] == gd.capacity;
        // Destination node
        // 终点
        sum(s in Services: s.destination == gd.destination) useService[gd.good][s] == 1;
        sum(s in Services: s.destination == gd.destination) x[gd.good][s] == gd.capacity;
        // Intermediate nodes
        // 中间节点
        forall(n in Nodes: n != gd.origin && n != gd.destination) {
          	sum(s in Services: s.destination == n) x[gd.good][s] == sum(s in Services: s.origin == n) x[gd.good][s];
        }
    }

    // Service capacity constraints
    // 服务容量约束
    forall(s in Services)
        s.modality == "Truck" || sum(gd in GoodsDetails) x[gd.good][s] <= s.capacity;

    // Non-negative transportation quantities
    // 非负运输量
    forall(gd in GoodsDetails, s in Services) {
        x[gd.good][s] >= 0;
    }
    
    forall(gd in GoodsDetails, n in Nodes) {
      	goodDepartureTime[gd.good][n] >= 0;
      	goodArrivalTime[gd.good][n] >= 0;
    }

    // Define auxiliary binary variable useService[gd][s]
    // 定义辅助二进制变量 useService[gd][s]
    forall(gd in GoodsDetails, s in Services) {
        // If the good has transportation quantity on service s, then useService is 1
        // 如果货物在服务 s 上有运输量，则 useService 为 1
        (x[gd.good][s] >= 1) => useService[gd.good][s] == 1;
        (x[gd.good][s] == 0) => useService[gd.good][s] == 0;
    }

    // Add time constraints for each used service
    // 为每个使用的服务添加时间约束
    forall(gd in GoodsDetails, s in Services) {
  		if (s.modality != "Truck") {
    		(useService[gd.good][s] == 1) => 
    		goodDepartureTime[gd.good][s.origin] == s.departuretime - LoadingTime[s.modality] &&
    		goodArrivalTime[gd.good][s.destination] == s.arrivaltime + UnloadingTime[s.modality] &&
    		gd.departuretime <= goodDepartureTime[gd.good][s.origin] &&
    		gd.arrivaltime >= goodArrivalTime[gd.good][s.destination];
  		} else {
    		(useService[gd.good][s] == 1) => 
    		goodArrivalTime[gd.good][s.destination] >= goodDepartureTime[gd.good][s.origin] + s.transittime * (1 + disasterimpact) + LoadingTime[s.modality] + UnloadingTime[s.modality] &&
    		gd.departuretime <= goodDepartureTime[gd.good][s.origin] &&
    		gd.arrivaltime >= goodArrivalTime[gd.good][s.destination];
  		}
	}
	
	forall(gd in GoodsDetails, n in Nodes) {
  		// If the good does not arrive at node n via any service, set arrival time to zero
  		(sum(s in Services: s.destination == n) useService[gd.good][s] == 0) => 
  		(goodArrivalTime[gd.good][n] == 0);

  		// If the good does not depart from node n via any service, set departure time to zero
  		(sum(s in Services: s.origin == n) useService[gd.good][s] == 0) => 
  		(goodDepartureTime[gd.good][n] == 0);
	}
	


    // Time constraints to connect consecutive services
    // 连接连续服务的时间约束
    forall(gd in GoodsDetails, s1 in Services, s2 in Services: s1.destination == s2.origin) {
  		// 当货物连续使用两个服务时，施加连接约束
  		(useService[gd.good][s1] == 1 && useService[gd.good][s2] == 1) => 
  		goodDepartureTime[gd.good][s2.origin] >= goodArrivalTime[gd.good][s1.destination];
	}  

    // Overtime penalty constraints
    // 超时惩罚约束
    forall(gd in GoodsDetails) {
        positiveDelay[gd.good] >= goodArrivalTime[gd.good][gd.destination] - gd.arrivaltime;
    }
}

execute {
    writeln("Transport Paths and Overtime Information:");
    // Output the transport path and status of each good
    // 输出每个货物的运输路径和状态
    for (var gd in GoodsDetails) {
        writeln("Good Name: ", gd.good);
        writeln("Transported Quantity: ", gd.capacity);
        writeln("Origin to destination: ", gd.origin, " to ", gd.destination);
        for (var s in Services) {
            if (x[gd.good][s].solutionValue > 0.1) {
                writeln("  - Service: ", s.modality, " from ", s.origin, " to ", s.destination, 
                        ", Transported Quantity: ", x[gd.good][s]);
            }
        }
        // Check if there is a time violation
        // 检查是否存在时间违规
        if (positiveDelay[gd.good] >= 1) {
            writeln("  - Status: Overtime");
        } else {
            writeln("  - Status: On Time");
        }
    }
}
