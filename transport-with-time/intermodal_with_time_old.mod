/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Jul 21, 2024 at 4:01:47 PM
 *********************************************/

using CPLEX;

// 运输服务的信息集合
// Set of all service information
tuple ServiceInfo {
    string modality;         // 运输方式 Mode of transport
    string origin;           // 起点 Origin node
    string destination;      // 终点 Destination node
    int capacity;            // 运输容量 Capacity of the service
    float departuretime;     // 出发时间 Departure time
    float arrivaltime;       // 到达时间 Arrival time
    float transittime;       // 运输时间 Transit time
    float transitcost;       // 运输成本 Transit cost
    float carbonemissions;   // 碳排放量 Carbon emissions
}

// 每个物品的详细信息集合
// Set of detailed information for each good
tuple GoodInfo {
    string good;             // 物品名称或标识 Name or identifier of the good
    string origin;           // 起点 Origin node
    string destination;      // 终点 Destination node
    int capacity;            // 容量 Capacity of the good
    float departuretime;     // 出发时间 Departure time
    float arrivaltime;       // 到达时间 Arrival time
    float penalty;           // 超时惩罚 Penalty for late delivery
}

{ServiceInfo} Services = ...; // 运输服务信息集合 Set of all service information
setof(string) Nodes = ...;     // 所有节点，包括起点、终点和转运节点 Set of all nodes, including origins, destinations, and transshipment nodes
setof(string) Modes = ...;     // 所有运输方式 Set of all transportation modes

{GoodInfo} GoodsDetails = ...; // 每个物品的详细信息集合 Set of detailed information for each good
setof(string) Goods = {gd.good | gd in GoodsDetails}; // 从GoodsDetails中提取物品集合 Set of goods extracted from GoodsDetails

dvar int+ x[Goods][Services]; // 每个物品在某个服务上的运输量 Transportation quantity of each good on each service
dvar boolean timeViolation[Goods]; // 时间违规变量 Time violation variable

float timelimit = ...;
float epgap = ...;
float disasterimpact = ...;

execute PRE_PROCESSING {
  cplex.tilim = timelimit;
  cplex.epgap = epgap;
}


// 目标函数：运输成本和超时成本
// Objective function: transportation cost and overtime cost
minimize 
    sum(gd in GoodsDetails, s in Services) s.transitcost * x[gd.good][s] // 运输成本 Transportation cost 
    + sum(gd in GoodsDetails, s in Services) s.carbonemissions * x[gd.good][s] // 碳排放成本 Carbon emissions cost
    + sum(gd in GoodsDetails) gd.penalty * timeViolation[gd.good] * gd.capacity; // 超时惩罚成本 Penalty cost for late delivery

// 约束条件
// Constraints
subject to {
    forall(gd in GoodsDetails) {
        // 每个物品从其起点出发，运输量等于其总量
        // Each good must depart from its origin with the total quantity equal to its capacity
        sum(s in Services: s.origin == gd.origin) x[gd.good][s] == gd.capacity;

        // 每个物品到达其终点，运输量等于其总量
        // Each good must arrive at its destination with the total quantity equal to its capacity
        sum(s in Services: s.destination == gd.destination) x[gd.good][s] == gd.capacity;

        // 物品的出发时间限制早于服务开始时间才能使用该服务
        // Goods can only use a service if their departure time is before or equal to the service's departure time
        forall(s in Services: s.origin == gd.origin)
            s.modality == "Truck" || x[gd.good][s] == 0 || gd.departuretime <= s.departuretime;

        // 如果服务到达时间超过物品的到达时间限制则超时
        // Time violation occurs if the arrival time of the service exceeds the good's arrival time limit
        forall(s in Services: s.destination == gd.destination)
            s.modality == "Truck" || x[gd.good][s] == 0 || s.arrivaltime <= gd.arrivaltime + 1e9 * timeViolation[gd.good];
            
        // 卡车在第最后一个服务的情况
    	// Trucks in last service: Time violation occurs if the arrival time of the service exceeds the good's arrival time limit
    	// arrival_time_of_previous_service + truck_service_transit_time <= good_arrivaltime
    	forall(s1 in Services, s2 in Services:
    		s1.modality != "Truck" && s2.origin == s1.destination && s2.modality == "Truck" && s2.destination == gd.destination) {
    		x[gd.good][s2] == 0 || s1.arrivaltime +  s2.transittime * (1 + disasterimpact) <= gd.arrivaltime + 1e9 * timeViolation[gd.good];  
		}
            	
        // 中间节点的物品平衡约束
        // Balance constraint at intermediate nodes
        forall(n in Nodes: n != gd.origin && n != gd.destination)
            sum(s in Services: s.destination == n) x[gd.good][s] == sum(s in Services: s.origin == n) x[gd.good][s];
            
         
    	// 确保卡车和非卡车运输服务的时间顺序合理
    	// Ensure time sequence is correct between truck and non-truck services
    	// arrival_time_of_previous_service + truck_service_transit_time <= next_service_departuretime
    	// 2 situation
    	
    	// 卡车在第一个服务的情况
    	// Trucks in first service ==> arrival_time_of_previous_service = 0
    	// truck_service_transit_time <= next_service_departuretime
    	forall(s1 in Services, s2 in Services:
    		s1.modality == "Truck" && s2.origin == s1.destination && s2.modality != "Truck") {
    		x[gd.good][s1] == 0 || s1.transittime * (1 + disasterimpact) <= s2.departuretime;  
		}
		
		// 卡车夹在两种服务之间的情况
		// Trucks caught between two services
		// arrival_time_of_previous_service + truck_service_transit_time <= next_service_departuretime
		forall(s1 in Services, s2 in Services, s3 in Services:
    		s1.destination == s2.origin && s2.destination == s3.origin &&
    		s1.modality != "Truck" && s2.modality == "Truck" && s3.modality != "Truck") {
    		x[gd.good][s2] == 0 || s1.arrivaltime + s2.transittime * (1 + disasterimpact) <= s3.departuretime;   		
		}        
		
    }

    // 确保顺序服务在到达和出发时间上可行
    // Ensure sequential services are feasible based on arrival and departure times
    forall(gd in GoodsDetails) {
        forall(s1 in Services, s2 in Services: s1.destination == s2.origin)
            s1.modality == "Truck" || s2.modality == "Truck" || x[gd.good][s1] == 0 || x[gd.good][s2] == 0 || s1.arrivaltime <= s2.departuretime;
    }

    // 每条服务上的总运输量不能超过其容量限制
	forall(s in Services)
    	s.modality == "Truck" || sum(gd in GoodsDetails) x[gd.good][s] <= s.capacity;
    
 
    // 确保非负运输量
    // Ensure non-negative transportation quantity
    forall(gd in GoodsDetails, s in Services) {
      	x[gd.good][s] >= 0;
    }
         
}

// 输出执行部分
// Execution block for output
execute {
    writeln("Transport Paths and Overtime Information:");
    // 输出每个货物的运输路径
    // Output the transportation path for each good
    for (var gd in GoodsDetails) {
        writeln("GoodName: ", gd.good);
        writeln("Transported Quantity: ", gd.capacity);
        writeln("Origin to destination: ", gd.origin, " to ", gd.destination);
        for (var s in Services) {
            if (x[gd.good][s] > 0) {
                writeln("  - Service: ", s.modality, " from ", s.origin, " to ", s.destination, 
                        ", Transported Quantity: ", x[gd.good][s]);
            }
        }
        // 检查是否超时
        // Check for overtime status
         if (timeViolation[gd.good] == 1) {
            writeln("  - Status: Overtime");
        } else {
            writeln("  - Status: On Time");
        }
        
    }
}