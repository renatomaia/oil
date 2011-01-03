public class server {
	public static void main(String[] args) {
		try {
			// initialize the ORB
			java.util.Properties props = new java.util.Properties();
			props.setProperty(
				"org.omg.PortableInterceptor.ORBInitializerClass.bidir_init",
				"org.jacorb.orb.giop.BiDirConnectionInitializer"); 
			org.omg.CORBA.ORB orb = org.omg.CORBA.ORB.init(args, props); 
			
			// get RootPOA
			org.omg.PortableServer.POA root_poa =
				org.omg.PortableServer.POAHelper.narrow(
					orb.resolve_initial_references("RootPOA"));
			
			// create POA policies
			org.omg.CORBA.Policy[] policies = new org.omg.CORBA.Policy[4];
			policies[0] = root_poa.create_lifespan_policy(
				org.omg.PortableServer.LifespanPolicyValue.TRANSIENT);
			policies[1] = root_poa.create_id_assignment_policy(
				org.omg.PortableServer.IdAssignmentPolicyValue.SYSTEM_ID);
			policies[2] = root_poa.create_implicit_activation_policy(
				org.omg.PortableServer.ImplicitActivationPolicyValue.IMPLICIT_ACTIVATION);
			org.omg.CORBA.Any any = orb.create_any(); 
			org.omg.BiDirPolicy.BidirectionalPolicyValueHelper.insert(
				any, org.omg.BiDirPolicy.BOTH.value); 
			policies[3] = orb.create_policy(
				org.omg.BiDirPolicy.BIDIRECTIONAL_POLICY_TYPE.value, any);
			
			// create new POA with the provided policies
			final org.omg.PortableServer.POA bidir_poa =
				root_poa.create_POA("BiDirPOA", root_poa.the_POAManager(), policies);
			bidir_poa.the_POAManager().activate();
			
			// create the service
			org.omg.CORBA.Object obj = bidir_poa.servant_to_reference(
				new TimeEventServicePOA() {
					public TimeEventTimer newtimer(final double rt,
					                               final TimeEventCallback cb)
					{
						try {
							return TimeEventTimerHelper.narrow(bidir_poa.servant_to_reference(
								new TimeEventTimerPOA() {
									private int m_count = 0;
									private Thread thread;
									public int count()
									{
										return m_count;
									}
									public boolean enable()
									{
										if (thread == null) {
											final long rate = (long)(rt*1000);
											final long start = java.lang.System.currentTimeMillis();
											thread = new java.lang.Thread("Timer") {
												public void run()
												{
													while (true) {
														cb.triggered(++m_count);
														long now = java.lang.System.currentTimeMillis();
														long elapsed = (now-start)%rate;
														try{ sleep(rate-elapsed); }
														catch(java.lang.InterruptedException ex) {}
													}
												}
											};
											thread.start();
											return true;
										}
										return false;
									}
									public boolean disable()
									{
										if (thread != null) {
											thread.stop();
											thread = null;
											return true;
										}
										return false;
									}
								}));
						} catch (org.omg.PortableServer.POAPackage.ServantNotActive ex) {
							return null;
						} catch (org.omg.PortableServer.POAPackage.WrongPolicy ex) {
							return null;
						}
					}
					public void print(java.lang.String msg)
					{
						System.out.println(msg);
					}
				});
			
			// output service's reference
			java.io.PrintWriter file = null;
			try {
				file = new java.io.PrintWriter(
					new java.io.BufferedWriter(
						new java.io.FileWriter("ref.ior")));
				file.println(orb.object_to_string(obj));
			} finally {
				try { if (file != null) file.close(); }
				catch (java.lang.Exception ex) { throw ex; }
			}
			
			// wait for invocations from clients
			java.lang.Object sync = new java.lang.Object();
			synchronized (sync) { sync.wait(); }
		// print eventual errors
		} catch(java.lang.Exception ex) {
			ex.printStackTrace();
		}
	}
}
