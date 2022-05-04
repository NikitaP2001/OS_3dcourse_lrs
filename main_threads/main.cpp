#include <iostream>
#include <cstring>
#include <string>
#include <cstdlib>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <sys/file.h>
#include <arpa/inet.h>

#include "main.hpp"

#ifdef DEBUG
std::mutex os_block;
#endif

#define F_PORT 8088
#define G_PORT 8089
#define TIME_WAIT 10


void f_main();
void g_main();
int f(int);
int g(int);

int server_listen_port(int PORT);
int client_connect_port(int PORT);


typedef void (*sa_sigaction_t)(int, siginfo_t *, void *);

int set_sig_handler(int socket, sa_sigaction_t handler);
void cli_sig_handler(int, siginfo_t *, void *);
void serv_sig_handler(int sig, siginfo_t *info, void *ucontext);

bool f_done, g_done;
int f_res = -1, g_res = -1;
int f_sock, g_sock;

bool f_got_arg, g_got_arg;

int main()
{
	pid_t pid_f, pid_g;
	int status, x_val;
	char buf[100];

	pid_f = fork();
	if (pid_f == 0) {
		SUCC("f_main started ");
		f_main();
		exit(0);
	}

	pid_g = fork();
	if (pid_g == 0) {
		SUCC("g_main started ");
		g_main();
		exit(0);
	}

	while ((f_sock = client_connect_port(F_PORT)) == -1) {
		ERROR("fail to connect f");
		sleep(1);
	}

	while ((g_sock = client_connect_port(G_PORT)) == -1)
		ERROR("fail to connect g");


	if (set_sig_handler(f_sock, cli_sig_handler) != 0)
		ERROR("set f_sock sig handler");

	if (set_sig_handler(g_sock, cli_sig_handler) != 0)
		ERROR("set g_sock sig handler");

	// request x
	std::cout << "Enter x:";
	std::cin >> x_val;
	
	std::string sbuf = std::to_string(x_val);
	strcpy(buf, sbuf.c_str());
	// send arg to f
	while (!f_got_arg) {
		INFO("cli sent: " << buf);
		if (send(f_sock, buf, strlen(buf) + 1, 0) <= 0)
			ERROR("send():" << strerror(errno));
		sleep(1);
	}

	// send arg to g
	while (!g_got_arg) {
		INFO("cli sent: " << buf);
		if (send(g_sock, buf, strlen(buf) + 1, 0) <= 0)
			ERROR("send():" << strerror(errno));
		sleep(1);

	}


	bool ask = true;
	time_t time_ask = time(NULL);
	sleep(1);
	while (!((g_done && f_done) || (f_done && (f_res == 0)) 
			|| (g_done && (g_res == 0)))) {

		sleep(1);

		if (ask && (time(NULL) - time_ask > TIME_WAIT) 
		&& !((g_done && f_done) || (f_done && (f_res == 0)) 
			|| (g_done && (g_res == 0)))) {

			std::cout << "Continue / stop / continue,"
				"not asking again: [c]/[s]/[C]: ";

			char c;
			std::cin >> c;
			if (c == 's')
				break;
			else if (c == 'C')
				ask = false;

			time_ask = time(NULL);
		}
	}

	// send message stop to funcs
	if (!f_done) {
		strcpy(buf, "stop");
		if (send(f_sock, buf, strlen(buf) + 1, 0) <= 0)
			ERROR("send():" << strerror(errno));
	}
	if (!g_done) {
		strcpy(buf, "stop");
		if (send(g_sock, buf, strlen(buf) + 1, 0) <= 0)
			ERROR("send():" << strerror(errno));
	}

	// write result to sout
	if (g_done && f_done)
		std::cout << "Result: " <<  f_res * g_res << std::endl;
	else if ((f_done && f_res == 0) || (g_done && g_res == 0))
		std::cout << "Result: " << 0 << std::endl;
	else 
		std::cout << "multiplication value cannot be determined" << std::endl;

	// wait child ps
	pid_f = waitpid(pid_f, &status, 0);
	if (WIFEXITED(status))
		INFO("f_main exited with status " << status);

	pid_g = waitpid(pid_g, &status, 0);
	if (WIFEXITED(status))
		INFO("g_main exited with status " << status);

	close(f_sock);
	close(g_sock);

	return 0;
}

/* install a SIGIO handler on socket
 *
 */
int set_sig_handler(int socket, sa_sigaction_t handler)
{
	struct sigaction sa;

	sigemptyset(&sa.sa_mask);
	sigaddset(&sa.sa_mask, SI_SIGIO);
	sa.sa_flags = SA_SIGINFO;
	sa.sa_sigaction = handler;
	if (sigaction(SIGIO, &sa, 0) == -1) {
		ERROR("sigaction(SIGIO):" << strerror(errno));
		return 1;
	}

	if (fcntl(socket, F_SETOWN, getpid()) == -1) {
		ERROR("fcntl(F_SETOWN):" << strerror(errno));
		return 1; 
	}

	if (fcntl(socket, F_SETFL, O_NONBLOCK | FASYNC) == -1) {
		ERROR("fcntl(F_SETFL):" << strerror(errno));
		return 1;
	}

	if (fcntl(socket, F_SETSIG, SIGIO) == -1) {
		ERROR("fcntl(F_SETSIG):" << strerror(errno));
		return 1;
	}

	return 0;
}

/* sigio handler for main routine
 */
void cli_sig_handler(int sig, siginfo_t *info, void *ucontext)
{
	char buf[100];
	int res;

	if (info->si_code == POLL_IN) {

		// which fd ?
		if (info->si_fd == f_sock) {

			if (recv(f_sock, buf, sizeof(buf), 0) > 0) {
				INFO("f_sock recvd: " << buf);

				if (strcmp(buf, "received") == 0)
					f_got_arg = true;
				else {
					f_res = atoi(buf);
					f_done = true;
					strcpy(buf, "received");
					send(f_sock, buf, strlen(buf) + 1, 0);
				}
			} else
				ERROR("recv():" << strerror(errno));

		} else {

			res = recv(g_sock, buf, sizeof(buf), 0);

			if (res > 0) {
				INFO("g_sock recvd: " << buf);

				if (strcmp(buf, "received") == 0)
					g_got_arg = true;
				else {
					g_res = atoi(buf);
					g_done = true;
					strcpy(buf, "received");
					send(g_sock, buf, strlen(buf) + 1, 0);
				}
			} else
				ERROR("recv():" << strerror(errno));

		}

	}


}

// globals for child ps
int sock;
bool res_delivered, have_x;
int result, x;

void serv_sig_handler(int sig, siginfo_t *info, void *ucontext)
{
	char buf[100];

	if (recv(sock, buf, sizeof(buf), 0) > 0) {
		INFO("serv recvd: " << buf);
		
		if (!strcmp(buf, "stop"))
			exit(0);
		else if (!strcmp(buf, "received"))
			res_delivered = true;
		else if (have_x == false) {
			x = atoi(buf);
			have_x = true;
			strcpy(buf, "received");
			send(sock, buf, strlen(buf) + 1, 0);
		}


	}

}

void f_main()
{
	sock = server_listen_port(F_PORT);

	if (set_sig_handler(sock, serv_sig_handler) != 0)
		ERROR("set sock sig handler");

	// wait for arg
	while (have_x != true)
		pause();
	
	result = f(x);

	char buf[100];
	std::string sbuf = std::to_string(result);
	strcpy(buf, sbuf.c_str());

	while (!res_delivered) {
		INFO("f_main sent: " << buf);
		if (send(sock, buf, strlen(buf) + 1, 0) <= 0)
			ERROR("send():" << strerror(errno));
		sleep(1);
	}
}

void g_main()
{
	sock = server_listen_port(G_PORT);

	if (set_sig_handler(sock, serv_sig_handler) != 0)
		ERROR("set sock sig handler");

	// wait for arg
	while (have_x != true)
		pause();

	result = g(x);

	char buf[100];
	std::string sbuf = std::to_string(result);
	strcpy(buf, sbuf.c_str());

	while (!res_delivered) {
		INFO("g_main sent: " << buf);
		if (send(sock, buf, strlen(buf) + 1, 0) <= 0)
			ERROR("send():" << strerror(errno));
		sleep(1);
	}

	close(sock);
}

int f(int x)
{
	x = (x * 123) % 10;
	x = (x + 321) % 10;
	if (x % 2 == 0 && x % 3 != 0)
		while (1) {}
	else if (x % 3 == 0)
		sleep(4);

	return x;
}

int g(int x)
{
	x = (x * 987) % 11;
	x = (x - 789) % 11;
	if (x % 3 == 0 && x % 2 != 0)
		while (1) {}
	else if (x % 2 == 0)
		sleep(5);

	return x;
}

// returns opened socket
int client_connect_port(int PORT)
{
	int sock = 0;
	struct sockaddr_in serv_addr;

	if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		ERROR("socket creation error");
		return -1;
	}

	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(PORT);

	// ipv4 to bin
	if (inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0) {
		ERROR("invalid address");
		close(sock);
		return -1;
	}

	if (connect(sock, (struct sockaddr*)&serv_addr, 
				sizeof(serv_addr)) < 0) {
		ERROR("connect():" << strerror(errno));
		close(sock);
		return -1;
	}

	return sock;
}

// returns opened socket
int server_listen_port(int PORT)
{
	int server_fd, new_socket;
	struct sockaddr_in address;
	int opt = 1;
	int addrlen = sizeof(sockaddr_in);
 
	// Creating socket file descriptor
	if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
		ERROR("socket failed");
		exit(EXIT_FAILURE);
	}
 
	// Forcefully attaching socket to the port 8080
	if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT,
	&opt, sizeof(opt))) {
		ERROR("setsockopt");
		close(server_fd);
		exit(EXIT_FAILURE);
	}
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = INADDR_ANY;
	address.sin_port = htons(PORT);
 
	// attach to port
	if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
		ERROR("bind failed");
		close(server_fd);
		exit(EXIT_FAILURE);
	}
	if (listen(server_fd, 3) < 0) {
		ERROR("listen");
		close(server_fd);
		exit(EXIT_FAILURE);
	}

	if ((new_socket = accept(server_fd, (struct sockaddr*)&address,
	(socklen_t*)&addrlen)) < 0) {
		ERROR("accept");
		close(server_fd);
		exit(EXIT_FAILURE);
	}

	return new_socket;
}
