public class client {
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
			
			// get proxy for remote service
			java.io.BufferedReader reader =
				new java.io.BufferedReader(new java.io.FileReader("ref.ior"));
			final TimeEventService service =
				TimeEventServiceHelper.narrow(orb.string_to_object(reader.readLine()));
			
			// create timers using the remote service
			for (int c=1; c<=3; ++c) {
				final int i = c;
				final TimeEventTimer timer = service.newtimer(i,
					TimeEventCallbackHelper.narrow(bidir_poa.servant_to_reference(
						new TimeEventCallbackPOA() {
							public void triggered(int count)
							{
								java.lang.String msg = i+": Triggered "+count+" times";
								if (i == 1) msg = '\n'+msg;
								service.print(msg);
							}
						})));
				timer.enable();
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
