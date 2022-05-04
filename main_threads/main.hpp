

#ifdef DEBUG
	#include <mutex>

	extern std::mutex os_block;

#define INFO(x) \
{ \
	std::lock_guard<std::mutex> guard(os_block); \
	std::cout << "[i] " << "[" << __FILE__ << "][" \
	<< __FUNCTION__ << "][l." << __LINE__ << "] " x << std::endl; \
} \
do {} while (0)

#define ERROR(x) \
{ \
	std::lock_guard<std::mutex> guard(os_block); \
	std::cerr << "[-]" << "[" << __FILE__ << "][" \
	<< __FUNCTION__ << "][l." << __LINE__ << "] " x << std::endl; \
} \
do {} while (0)

#define SUCC(x) \
{ \
	std::lock_guard<std::mutex> guard(os_block); \
	std::cout << "[+]" << "[" << __FILE__ << "][" \
	<< __FUNCTION__ << "][l." << __LINE__ << "] " x << std::endl; \
} \
do {} while (0)

#else
#define INFO(x) do {} while (0)
#define ERROR(x) do {} while (0)
#define SUCC(x) do {} while (0)
#endif

