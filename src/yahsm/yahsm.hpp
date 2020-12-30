#ifndef YAHSM_HPP
#define YAHSM_HPP

// This code is from:
// Yet Another Hierarchical State Machine
// by Stefan Heinzmann
// Overload issue 64 December 2004
// http://www.state-machine.com/resources/Heinzmann04.pdf

// This is a basic implementation of UML Statecharts. The key observation is
// that the machine can only be in a leaf state at any given time. The composite
// states are only traversed, never final. Only the leaf states are ever
// instantiated. The composite states are only mechanisms used to generate code.
// They are never instantiated.

// Top State, Composite State and Leaf State
////////////////////////////////////////////////////////////////////////////////

template <typename H>
struct TopState
{
    using Host = H;
    using Base = void;
    virtual void handler(Host&) const = 0;
    [[nodiscard]] virtual unsigned id() const = 0;
    virtual ~TopState() = default;
};

template <typename H, unsigned Id, typename B>
struct CompState;

template <typename H, unsigned Id, typename B = CompState<H, 0, TopState<H>>>
struct CompState : B
{
    using Base = B;
    using This = CompState<H, Id, Base>;
    template <typename X>
    void handle(H& h, const X& x) const { Base::handle(h, x); }
    static void init(H& /*unused*/); // no implementation
    static void entry(H& /*unused*/) { }
    static void exit(H& /*unused*/) { }
};

template <typename H>
struct CompState<H, 0, TopState<H>> : TopState<H>
{
    using Base = TopState<H>;
    using This = CompState<H, 0, Base>;
    template <typename X>
    void handle(H& /*unused*/, const X& /*unused*/) const { }
    static void init(H& /*unused*/); // no implementation
    static void entry(H& /*unused*/) { }
    static void exit(H& /*unused*/) { }
};

template <typename H, unsigned Id, typename B = CompState<H, 0, TopState<H>>>
struct LeafState : B
{
    using Host = H;
    using Base = B;
    using This = LeafState<H, Id, Base>;
    template <typename X>
    void handle(H& h, const X& x) const { Base::handle(h, x); }
    virtual void handler(H& h) const { handle(h, *this); }
    [[nodiscard]] virtual unsigned id() const { return Id; }
    static void init(H& h) { h.next(Obj); } // don't specialize this
    static void entry(H& /*unused*/) { }
    static void exit(H& /*unused*/) { }
    static const LeafState Obj; // only the leaf states have instances
};

template <typename H, unsigned Id, typename B>
const LeafState<H, Id, B> LeafState<H, Id, B>::Obj;

// Transition
////////////////////////////////////////////////////////////////////////////////

// A gadget from Herb Sutter's GotW #71 -- depends on SFINAE
template <class D, class B>
class IsDerivedFrom
{
    class Yes
    {
        char m_a[1];
    };
    class No
    {
        char m_a[10];
    };
    static Yes test(B*); // undefined
    static No test(...); // undefined
public:
    static constexpr char Res = (sizeof(test(static_cast<D*>(0))) == sizeof(Yes))
        ? 1
        : 0;
};

template <bool>
class Bool
{
};

template <typename C, typename S, typename T>
// Current, Source, Target
struct Tran
{
    using Host = typename C::Host;
    using CurrentBase = typename C::Base;
    using SourceBase = typename S::Base;
    using TargetBase = typename T::Base;

    enum
    { // work out when to terminate template recursion
        TargetBase_Derivies_From_CurrentBase
        = IsDerivedFrom<TargetBase, CurrentBase>::Res,

        Source_Derivies_From_CurrentBase = IsDerivedFrom<S, CurrentBase>::Res,

        Source_Derivies_From_Current = IsDerivedFrom<S, C>::Res,

        Current_Derivies_From_Source = IsDerivedFrom<C, S>::Res,

        Exit_Stop = TargetBase_Derivies_From_CurrentBase
            && Source_Derivies_From_Current,

        Entry_Stop = Source_Derivies_From_Current
            || (Source_Derivies_From_CurrentBase && !Current_Derivies_From_Source)
    };

    // overloading is used to stop recursion. The more natural template
    // specialization method would require to specialize the inner template
    // without specializing the outer one, which is forbidden.
    static void exit_actions(Host& /*unused*/, Bool<true> /*unused*/) { }
    static void exit_actions(Host& h, Bool<false> /*unused*/)
    {
        C::exit(h);
        Tran<CurrentBase, S, T>::exit_actions(h, Bool<Exit_Stop>());
    }
    static void entry_actions(Host& /*unused*/, Bool<true> /*unused*/) { }
    static void entry_actions(Host& h, Bool<false> /*unused*/)
    {
        Tran<CurrentBase, S, T>::entry_actions(h, Bool<Entry_Stop>());
        C::entry(h);
    }
    Tran(Host& h)
        : m_host(h)
    {
        exit_actions(m_host, Bool<false>());
    }
    ~Tran()
    {
        Tran<T, S, T>::entry_actions(m_host, Bool<false>());
        T::init(m_host);
    }
    Host& m_host;
};

// InitalStateSetup
////////////////////////////////////////////////////////////////////////////////

template <typename T>
struct InitalStateSetup
{
    using Host = typename T::Host;
    InitalStateSetup(Host& h)
        : m_host(h)
    {
    }
    ~InitalStateSetup()
    {
        T::entry(m_host);
        T::init(m_host);
    }

private:
    Host& m_host;
};

#endif // YAHSM_HPP
