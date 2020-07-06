#ifndef RINGBUFFER_HPP
#define RINGBUFFER_HPP

#include <cstddef>

template <typename T, size_t N>
class ringbuffer
{
public:
    using value_type = T;

    bool push(const T x)
    {
        if (m_size == N)
        {
            return false;
        }
        m_data[m_write_index] = x; // NOLINT do not use array subscript
        ++m_write_index;
        if (m_write_index == N)
        {
            m_write_index = 0;
        }
        ++m_size;
        return true;
    }

    bool pop()
    {
        if (m_size == 0)
        {
            return false;
        }
        ++m_read_index;
        if (m_read_index == N)
        {
            m_read_index = 0;
        }
        --m_size;
        return true;
    }

    T& operator[](const size_t i)
    {
        size_t j = (m_read_index + i) % N;
        return m_data[j]; // NOLINT do not use array subscript
    }

    size_t size()
    {
        return m_size;
    }

    bool empty()
    {
        return m_size == 0;
    }

    constexpr size_t capacity()
    {
        return N;
    }

private:
    value_type m_data[N]{};
    static constexpr size_t m_max_index{N - 1};
    size_t m_write_index{0};
    size_t m_read_index{0};
    size_t m_size{0};
};

#endif // RINGBUFFER_HPP