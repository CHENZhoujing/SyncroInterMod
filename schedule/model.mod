/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Sep 23, 2024 at 7:42:37 PM
 *********************************************/

// 数据输入
int N = ...; // 生产机器数量
int M = ...; // 重置机数量
int T = ...; // 系统运行天数
int TotalTime = T * 1440; // 总运行时间，分钟
int P[i in 1..N] = ...; // 生产时间数组

int D = 122; // 重置时间

// 计算每台机器的最大重置次数
int MaxResets[i in 1..N] = ceil(TotalTime / (P[i] + D));


// 决策变量
dvar interval s[i in 1..N] in 0..TotalTime; // 初始开机时间，机器的运行任务
dvar boolean x[i in 1..N][n in 0..MaxResets[i]-1]; // 重置任务是否执行的二进制变量

// 定义重置机资源
cumulFunction resets = sum(i in 1..N, n in 0..MaxResets[i]-1) pulse((startOf(s[i]) + n * (P[i] + D)), D) * x[i][n];

// 人工干预计数
dvar int+ manualInterventions;

// 目标函数
minimize manualInterventions;

subject to {
  // 初始化人工干预计数
  manualInterventions == sum(i in 1..N, n in 0..MaxResets[i]-1)
                          (1 - x[i][n]);

  // 对于每台机器
  forall(i in 1..N) {
    // 对于每次重置
    forall(n in 0..MaxResets[i]-1) {
      // 计算重置开始时间
      float resetStart = startOf(s[i]) + P[i] + n * (P[i] + D);
      
      // 如果重置在总时间内，定义重置任务
      if (resetStart + D <= TotalTime) {
        // 使用重置机时，重置任务的开始时间
        x[i][n] => (startOf(s[i]) + n * (P[i] + D)) in 0..TotalTime;
      }
    }
  }

  // 重置机容量限制
  alwaysIn(resets, 0, TotalTime, 0, M);
}
