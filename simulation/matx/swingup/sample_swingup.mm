#define LOGMAX 4000
Integer cmd, count;
Real smtime;
Matrix u, y;
Array data;


// センサとアクチュエータ関連の変数 (hardware.mmで使用される)
Matrix mp_data, PtoMR;

//-----------------------------------
//パラメータ、オブザーバの宣言開始
//-----------------------------------
Matrix Ahd,Bhd,Chd,Dhd,Jhd,F;	//パラメータ
Matrix z;						//オブザーバ
Real r_max, theta_min;			//角度と入力可能範囲の制限
Real pre_r, pre_theta, pre_dt;	//過去の位置、角度、角速度
Real l,M,m,a,a,f,g,c,J,n,k;		//各定数
//-----------------------------------
//ここまで
//-----------------------------------


// メイン関数
Func void main()
{
	void para_init(), var_init();
	void on_task(), break_task(), off_task_loop();
	void machine_ready(), machine_stop(), data_save();

	para_init();			// パラメータの初期化
	var_init();             // 変数の初期化
	machine_ready();        // 実験装置の準備

	rtSetClock(smtime);     // サンプリング周期の設定
	rtSetTask(on_task);		// オンライン関数の設定(制御)
	rtSetBreak(break_task); // 割り込みキーに対応する関数の設定

	rtStart();              // リアルタイム制御開始
	off_task_loop();        // オフライン関数
	rtStop();               // リアルタイム制御終了

	machine_stop();         // 実験装置を停止

	data_save();			// データを保存する
}
// パラメータの初期化
Func void para_init()
{
	read Ahd,Bhd,Chd,Dhd,Jhd,F <- "para_swing.mx";
}

// 変数の初期化
Func void var_init()
{
	smtime = 0.005;		// サンプリング周期 [s]
	cmd = 0;			// 制御出力を抑制
	count = 0;			// ロギングデータの数
	data = Z(3,LOGMAX); // ロギングデータを保存する場所

	
	u = [0.0];			// 入力 [v]	
	z = [0 0]';			//オブザーバの初期状態
	
	r_max = 0.08;
	theta_min = 15.0;
	
	
	l = 0.12;
	M = 0.816729; 
	m = 0.040;
	a = 0.687866;
	f = 9.41392;
	g = 9.80665;
	c = 0.0002089;
	J = 0.00039;
	
	pre_r = 0.0;
	pre_dt = 0.0;
	pre_ddt = 0.0;
	E0 = 0.0;
	k = 100.0;
	n = 0.75;
	
	pre_r = 0.0;
	pre_theta = -180.0/180.0*PI;
	pre_dt = 0.0;
}

// オンライン関数
Func void on_task()
{
	Matrix sensor();
	void actuator();

	
	//---------------------
	//ローカル変数の宣言
	//---------------------
	Matrix xh,xref;
	Real r,theta,dr,dt;
	Real sign_dtct, sat_ng;
	Real E,v;
	Integer isSwinging;
	//---------------------
	//ここまで
	//---------------------
	
	
	y = sensor();		// センサから入力

	
	//-----------------------
	//ローカル変数の初期化
	//-----------------------
	r = 0.0;
	theta = 0.0;
	dr = 0.0;
	dt = 0.0;
	ddt = 0.0;
	E = 0.0;
	//-----------------------
	//ここまで
	//-----------------------
	
	
	
	//-------------
	//角度の補正
	//-------------
	theta = y(2);	//センサーが測定した振子の角度
	
	//角が正の時
	if(0 < theta)
	{
		//角が180度オーバーの時負へ
		while(PI < theta)
		{
			theta = theta - 2.0*PI;
		}
	}
	//角が負の時
	else
	{
		//角が-180度オーバーの時正へ
		while(theta < -PI)
		{
			theta = theta + 2.0*PI;
		}
	}
	
	y(2) = theta;	//補正済みの角度を格納
	//-----------
	//ここまで
	//-----------
	
	
	//----------------------------
	//入力とオブザーバの処理開始
	//----------------------------
	xh = Chd*z + Dhd*y;				//状態の推定値
	xref = [0.0 0.0 0.0 0.0]';		//状態の目標値
	
	
		//-------------------------
		//振り上げ安定化作業開始
		//-------------------------
		r = y(1);
		//------------------
		//dr,dt,ddtの計算
		//------------------
		
		isSwinging = 1;
		//------------------
		//ここまで
		//------------------
	
	
		//振子の角度が安定化を始める角度にあり且つ台車の位置が入力可能範囲にある場合
		if(abs(theta) <= (theta_min/180*PI) && abs(r) < r_max)
		{
			isSwinging = 0;
		}
	
		//振子の角度が安定化を始める角度にない場合
		if((theta_min/180*PI) < abs(theta))
		{
			isSwinging = 1;
		}
	
		//---------------
		//振り上げ作業
		//---------------
		if(isSwinging == 1)
		{
			//力学的エネルギーEの計算
			E = (J+m*l*l)*dt*dt/2 + m*g*l*(cos(theta) -1);
	
			//------------
			//dr,dt,ddtの計算
			//------------
			dr = (r - pre_r)/smtime;
			dt = (theta - pre_theta)/smtime;
			ddt = (dt - pre_dt)/smtime;
			pre_r = r;
			pre_theta = theta;
			pre_dt = dt;
		
		
		
			//sign(dt*cos(theta))の計算
			sign_dtct = 0;
			if(dt*cos(theta) < 0)
			{
				sign_dtct = -1;
			}
			else if(0 < dt*cos(theta))
			{
				sign_dtct = 1;
			}
			else
			{
				sign_dtct = 0;
			}
	
			//sat_ngの計算
			sat_ng = max(-n*g, min(n*g, k*(E - E0)*sign_dtct));
		
	
			//台車の加速目標vの計算
			v = -c*dt/(m*l*cos(theta)) + sat_ng;
	
			//入力値uの計算
			u = [(f*dr - m*l*dt*dt*sin(theta) + m*l*ddt*cos(theta) + (M + m)*v)/a];
	
			//台車の位置が入力可能範囲外で且つ進行方向が台車の端側の場合
			if(r_max < abs(r) && 0 < r*u(1,1))
			{
				u = [0];
			}
		}
		//-------------
		//安定化作業
		//-------------
		else
		{
			u = [F*(xref - xh)];
		}	
		//-------------------------
		//ここまで
		//-------------------------
		//入力電圧の制限
		if(u(1) < -15.0)
		{
			u(1) = -15.0;
		}
		else if(15.0 < u(1))
		{
			u(1) = 15.0;
		}
		
		z = Ahd*z + Bhd*y + Jhd*u;		//オブザーバの状態の更新
		//----------------------------
		//ここまで
		//---------------------------
	
	
		// リハーサル中でなければ
		if (cmd == 1 && ! rtIsRehearsal()) {
			actuator(u(1));				// アクチュエータへ出力
		}

	
		// データのロギング
		if (cmd == 1 && count < LOGMAX) {
			count++;
			data(1:1, count) = u;
			data(2:3, count) = y;
		}
	}

// オフライン関数
Func void off_task_loop()
{
	Integer end_flag;

	end_flag = 0;

	gotoxy(5, 6);
	printf("'c': アクチュエータへ出力開始");
	gotoxy(5, 7);
	printf("ESC: アクチュエータへ出力停止");

	do {
		gotoxy(5, 11);
		printf("  台車位置 = %8.4f[m], 振子角度 = %8.4f[deg]",
			y(1), y(2)/PI*180);
		gotoxy(5, 12);
		printf("入力 = %10.4f[N]", u(1));

		gotoxy(5, 14);
		printf("データ数 = %4d, 時間 = %7.3f [s]", count, count*smtime);
		if (rtIsTimeOut()) {
			gotoxy(5, 18);
			warning("\n時間切れ !\n");
			break;
		}

		if (kbhit()) {
			switch (getch()) {
			  case 0x1b:            /* ESC */
				end_flag = 1;
				break;
		/* 'c' */  case 0x43: // アクチュエータへ出力開始
		/* 'C' */  case 0x63: // If 'c' or 'C' is 
				      // pressed, start motor
				cmd = 1;
				break;
			  default:
				break;
			}
		}
    } while ( ! end_flag);  // If end_flag != 0, END
}

// 割り込みキーに対応する関数
Func void break_task()
{
	void machine_stop();

	rtStop();
	machine_stop(); // 実験装置停止
}

// 実験装置の準備
Func void machine_ready()
{
	void sensor_init(), actuator_init();

	sensor_init();                  // センサの初期化
	actuator_init();                // アクチュエータの初期化

	gotoxy(5,5);
	printf("台車の初期位置 : レールの中央");
	gotoxy(5,6);
	printf("振子の初期位置 : 真下");
	gotoxy(5,9);
	pause "台車と振子を初期位置に移動し，リターンキーを入力して下さい。";
	gotoxy(5,9);
	printf("                                                            ");
	gotoxy(5,9);
	pause "リターンキーを入力すると，制御が開始されます。";
	clear;
}

// 実験装置停止
Func void machine_stop()
{
	void actuator_stop();

	actuator_stop();
}

// データのファイルへの保存
Func void data_save()
{
	String filename;
	Array TT;

	filename = "data";
	read filename;

	if (count > 1) {
		TT = [0:count-1]*smtime;
		print [[TT][data(:,1:count)]] >> filename + ".mat";
	}
}
